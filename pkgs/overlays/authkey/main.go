// authkey issues and rotates Tailscale/headscale pre-auth keys for use in this
// repository. It is not meant as a standalone tool — the ragenix rotation is
// specific to my setup.
//
// One binary, three control planes selected by a short name:
//
//	authkey kradalby   # Tailscale SaaS (kradalby.no tailnet)
//	authkey headscale  # headscale.kradalby.no
//	authkey sfiber     # headscale.sandefjordfiber.no
//	authkey all        # all three, each into its default secret
//
// headscale main (0.30+) speaks the Tailscale-compatible v2 OAuth + key API, so
// the same Tailscale Go client works against it by pointing BaseURL/token URL at
// the headscale instance.
//
// OAuth client credentials are resolved from the ts1p vault via the `secret`
// CLI (setec → 1Password); no env vars needed.
package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path"
	"strings"
	"time"

	"golang.org/x/oauth2/clientcredentials"
	"tailscale.com/client/tailscale"
)

const (
	secretRulesGitPath = "git/dotfiles/secrets/secrets.nix"
	secretsDirGitPath  = "git/dotfiles/secrets"
)

type platform struct {
	baseURL  string // "" → api.tailscale.com (Tailscale SaaS)
	tokenURL string
	tailnet  string
	secret   string // default ragenix .age file to rotate
	credID   string // ts1p secret name holding the OAuth client id
	credKey  string // ts1p secret name holding the OAuth client secret
}

// ponytail: confirm headscale tokenURL path + tailnet segment against the live
// server (v2 OAuth is main-only, undocumented); fix here if they differ.
var platforms = map[string]platform{
	"kradalby": {
		tokenURL: "https://login.tailscale.com/api/v2/oauth/token",
		tailnet:  "kradalby.no",
		secret:   "tailscale-preauthkey.age",
		credID:   "authkey-kradalby-client-id",
		credKey:  "authkey-kradalby-client-secret",
	},
	"headscale": {
		baseURL:  "https://headscale.kradalby.no",
		tokenURL: "https://headscale.kradalby.no/api/v2/oauth/token",
		tailnet:  "-",
		secret:   "headscale-client-preauthkey.age",
		credID:   "authkey-headscale-client-id",
		credKey:  "authkey-headscale-client-secret",
	},
	"sfiber": {
		baseURL:  "https://headscale.sandefjordfiber.no",
		tokenURL: "https://headscale.sandefjordfiber.no/api/v2/oauth/token",
		tailnet:  "-",
		secret:   "headscale-sfiber-client-preauthkey.age",
		credID:   "authkey-sfiber-client-id",
		credKey:  "authkey-sfiber-client-secret",
	},
}

// order is the fixed iteration order for the "all" target.
var order = []string{"kradalby", "headscale", "sfiber"}

var (
	tags   = flag.String("tags", "tag:server", "comma-separated tags to stamp on the key")
	secret = flag.String("secret", "", "ragenix .age secret to rotate, overrides the platform default")
	expiry = flag.Duration("expiry", 24*time.Hour, "key expiry")
	rotate = flag.Bool("rotate", false, "write the key into the ragenix secret (default: print to stdout)")
	commit = flag.Bool("commit", false, "git commit the rotated secret (implies -rotate)")
)

func usage() {
	fmt.Fprintf(os.Stderr, "usage: authkey <kradalby|headscale|sfiber|all> [flags]\n")
	flag.PrintDefaults()
}

func main() {
	flag.Usage = usage
	flag.Parse()

	if flag.NArg() != 1 {
		usage()
		os.Exit(2)
	}
	target := flag.Arg(0)
	if *commit {
		*rotate = true
	}

	tailscale.I_Acknowledge_This_API_Is_Unstable = true

	tagList := parseTags(*tags)
	if len(tagList) == 0 {
		log.Fatalf("at least one tag is required")
	}

	var names []string
	switch target {
	case "all":
		if *secret != "" {
			log.Fatalf("-secret cannot be combined with 'all' (each platform has its own secret)")
		}
		names = order
	default:
		if _, ok := platforms[target]; !ok {
			log.Fatalf("unknown platform %q (want: kradalby, headscale, sfiber, all)", target)
		}
		names = []string{target}
	}

	for _, name := range names {
		p := platforms[name]
		secretFile := p.secret
		if *secret != "" {
			secretFile = *secret
		}

		key, expires, err := issue(p, tagList, *expiry)
		if err != nil {
			log.Fatalf("[%s] issuing key: %s", name, err)
		}

		if *rotate {
			if err := rotateSecret(secretFile, key, *commit); err != nil {
				log.Fatalf("[%s] rotating %s: %s", name, secretFile, err)
			}
			log.Printf("[%s] rotated %s, expiring %s", name, secretFile, expires.Format(time.RFC3339))
		} else {
			log.Printf("[%s] key expiring %s", name, expires.Format(time.RFC3339))
			if len(names) > 1 {
				fmt.Printf("%s\t%s\n", name, key)
			} else {
				os.Stdout.WriteString(key)
			}
		}
	}
}

func parseTags(s string) []string {
	var out []string
	for _, t := range strings.Split(s, ",") {
		if t = strings.TrimSpace(t); t != "" {
			out = append(out, t)
		}
	}
	return out
}

// issue mints a reusable, preauthorized key on the platform's control plane.
func issue(p platform, tagList []string, expiry time.Duration) (string, time.Time, error) {
	clientID, err := resolveSecret(p.credID)
	if err != nil {
		return "", time.Time{}, fmt.Errorf("resolving client id: %w", err)
	}
	clientSecret, err := resolveSecret(p.credKey)
	if err != nil {
		return "", time.Time{}, fmt.Errorf("resolving client secret: %w", err)
	}

	creds := clientcredentials.Config{
		ClientID:     clientID,
		ClientSecret: clientSecret,
		TokenURL:     p.tokenURL,
	}
	c := tailscale.NewClient(p.tailnet, nil)
	if p.baseURL != "" {
		c.BaseURL = p.baseURL
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	c.HTTPClient = creds.Client(ctx)

	key, meta, err := c.CreateKeyWithExpiry(ctx, tailscale.KeyCapabilities{
		Devices: tailscale.KeyDeviceCapabilities{
			Create: tailscale.KeyDeviceCreateCapabilities{
				Reusable:      true,
				Ephemeral:     false,
				Preauthorized: true,
				Tags:          tagList,
			},
		},
	}, expiry)
	if err != nil {
		return "", time.Time{}, err
	}
	return key, meta.Expires, nil
}

// resolveSecret reads a value from the ts1p vault via the `secret` CLI (on PATH,
// like ragenix/git below).
func resolveSecret(name string) (string, error) {
	out, err := exec.Command("secret", name).Output()
	if err != nil {
		return "", fmt.Errorf("secret %s: %w", name, err)
	}
	v := strings.TrimSpace(string(out))
	if v == "" {
		return "", fmt.Errorf("secret %s: empty", name)
	}
	return v, nil
}

// rotateSecret writes key into the ragenix .age file and optionally commits it.
func rotateSecret(secretFile, key string, commit bool) error {
	home, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("getting home dir: %w", err)
	}
	rulesPath := path.Join(home, secretRulesGitPath)
	keyPath := path.Join(home, secretsDirGitPath, secretFile)

	cmd := exec.Command("bash", "-c",
		fmt.Sprintf(`echo "%s" | ragenix --editor=fake-editor --rules=%s --edit=%s`,
			key, rulesPath, keyPath))
	if out, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("ragenix: %s: %w", out, err)
	}

	if commit {
		cmd := exec.Command("git", "commit", "--signoff",
			"--message", fmt.Sprintf("secret: rotate %s", strings.TrimSuffix(secretFile, ".age")),
			keyPath)
		if out, err := cmd.CombinedOutput(); err != nil {
			return fmt.Errorf("git commit: %s: %w", out, err)
		}
	}
	return nil
}
