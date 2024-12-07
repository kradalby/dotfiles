// ts-preauthkey is a tool made for use in this
// repository, it is not meant to be used as a standalone tool.
// It is used to rotate the preauthkey for a tailscale in my
// ragenix secret store.
// Technically, the "issue a new preauthkey" part can be used outside
// of this repository, but the ragenix part is very specific to my setup.

package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path"
	"time"

	"golang.org/x/oauth2/clientcredentials"
	"tailscale.com/client/tailscale"
	"tailscale.com/envknob"
)

const (
	secretRulesGitPath  = "git/dotfiles/secrets/secrets.nix"
	tailscaleKeyGitPath = "git/dotfiles/secrets/tailscale-preauthkey.age"
)

var (
	tsClientID     = envknob.String("TS_ROTATE_CLIENT_ID")
	tsClientSecret = envknob.String("TS_ROTATE_CLIENT_SECRET")
	tsDomain       = envknob.String("TS_ROTATE_DOMAIN")
)

var (
	rotate = flag.Bool("rotate", false, "path to ragenix file to rotate")
	commit = flag.Bool("commit", false, "commit the changes to git")
)

func main() {
	flag.Parse()

	tailscale.I_Acknowledge_This_API_Is_Unstable = true

	if tsClientID == "" || tsClientSecret == "" || tsDomain == "" {
		log.Fatalf(
			"missing env variables, please set: TS_ROTATE_CLIENT_ID, TS_ROTATE_CLIENT_SECRET, TS_ROTATE_DOMAIN",
		)
	}

	credentials := clientcredentials.Config{
		ClientID:     tsClientID,
		ClientSecret: tsClientSecret,
		TokenURL:     "https://login.tailscale.com/api/v2/oauth/token",
	}
	tsClient := tailscale.NewClient(tsDomain, nil)
	tsClient.HTTPClient = credentials.Client(context.Background())

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	key, meta, err := tsClient.CreateKeyWithExpiry(ctx, tailscale.KeyCapabilities{
		Devices: tailscale.KeyDeviceCapabilities{
			Create: tailscale.KeyDeviceCreateCapabilities{
				Reusable:      true,
				Ephemeral:     false,
				Preauthorized: true,
				Tags:          []string{"tag:server"},
			},
		},
	}, 24*time.Hour)

	if err != nil {
		log.Fatalf("creating key: %s", err)
	}

	if *rotate {
		home, err := os.UserHomeDir()
		if err != nil {
			log.Fatalf("getting home dir: %s", err)
		}

		secretRulesPath := path.Join(home, secretRulesGitPath)
		tsKeyPath := path.Join(home, tailscaleKeyGitPath)

		cmd := exec.Command(
			"bash",
			"-c",
			fmt.Sprintf(`echo "%s" | ragenix --editor=fake-editor --rules=%s --edit=%s`, key, secretRulesPath, tsKeyPath),
		)
		output, err := cmd.Output()
		if err != nil {
			log.Fatalf("running ragenix: %s %s", output, err)
		}
		log.Printf("key rotated with ragenix")

		if *commit {
			cmd := exec.Command(
				"git", "commit", "--signoff", "--message", "secret: rotate tailscale preauth key", tsKeyPath,
			)
			output, err := cmd.Output()
			if err != nil {
				log.Fatalf("commiting to git: %s %s", output, err)
			}
			log.Printf("key commited to git")
		}

		log.Printf("key rotated, expiring: %s", meta.Expires.Format(time.RFC3339))
	} else {
		log.Printf("key rotated, expiring: %s\n", meta.Expires.Format(time.RFC3339))
		// Write key to stdout so it can be used in scripts
		os.Stdout.WriteString(key)
	}
}
