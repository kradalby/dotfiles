package builders

import (
	"encoding/json"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
)

// devLDN mirrors the proven-working entry from the end-to-end validation.
var devLDN = Builder{
	Name:              "dev.ldn",
	Host:              "dev.ldn",
	HostName:          "dev.ldn.fap.no",
	Systems:           []string{"x86_64-linux"},
	SSHUser:           "root",
	SSHKey:            "/Users/kradalby/.ssh/id_ed25519",
	MaxJobs:           4,
	SpeedFactor:       4,
	SupportedFeatures: []string{"big-parallel", "kvm", "nixos-test"},
	PublicHostKey:     "c3NoLWtleQ==",
}

func TestSpec(t *testing.T) {
	tests := []struct {
		name string
		b    Builder
		want string
	}{
		{
			name: "proven dev.ldn line",
			b:    devLDN,
			want: "ssh-ng://root@dev.ldn.fap.no x86_64-linux /Users/kradalby/.ssh/id_ed25519 4 4 big-parallel,kvm,nixos-test - c3NoLWtleQ==",
		},
		{
			name: "multiple systems comma-joined",
			b:    Builder{HostName: "h", SSHUser: "root", Systems: []string{"x86_64-linux", "aarch64-linux"}, MaxJobs: 2, SpeedFactor: 1},
			want: "ssh-ng://root@h x86_64-linux,aarch64-linux - 2 1 - - -",
		},
		{
			name: "no user, empty optionals become dashes",
			b:    Builder{HostName: "h", Systems: []string{"x86_64-linux"}},
			want: "ssh-ng://h x86_64-linux - - - - - -",
		},
		{
			name: "mandatory features rendered, pubkey present",
			b:    Builder{HostName: "h", SSHUser: "u", Systems: []string{"s"}, SupportedFeatures: []string{"kvm"}, MandatoryFeatures: []string{"big-parallel"}, PublicHostKey: "K"},
			want: "ssh-ng://u@h s - - - kvm big-parallel K",
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			require.Equal(t, tt.want, tt.b.Spec())
			require.Len(t, strings.Fields(tt.b.Spec()), 8, "spec must have 8 fields: %q", tt.b.Spec())
		})
	}
}

func TestNixConfigDefault(t *testing.T) {
	got := NixConfig([]Builder{devLDN}, false, "", "")
	want := "builders = " + devLDN.Spec() + "\nmax-jobs = 0\nbuilders-use-substitutes = true"
	require.Equal(t, want, got)
}

func TestNixConfigMultipleBuildersJoin(t *testing.T) {
	b2 := Builder{Name: "b2", HostName: "h2", SSHUser: "root", Systems: []string{"x86_64-linux"}}
	got := NixConfig([]Builder{devLDN, b2}, false, "", "")
	wantBuilders := "builders = " + devLDN.Spec() + " ; " + b2.Spec()
	require.True(t, strings.HasPrefix(got, wantBuilders),
		"builders should be ';'-joined\n got: %q\nwant prefix: %q", got, wantBuilders)
}

func TestNixConfigMerge(t *testing.T) {
	got := NixConfig([]Builder{devLDN}, true, "@/etc/nix/machines", "")
	require.True(t, strings.HasPrefix(got, "builders = @/etc/nix/machines ; "+devLDN.Spec()),
		"merge must prepend existing builders, got: %q", got)
	require.NotContains(t, got, "max-jobs = 0", "merge must NOT force max-jobs=0 (keeps local building)")
	require.Contains(t, got, "builders-use-substitutes = true")
}

func TestNixConfigExtendsBase(t *testing.T) {
	got := NixConfig([]Builder{devLDN}, false, "", "experimental-features = nix-command flakes")
	require.True(t, strings.HasPrefix(got, "experimental-features = nix-command flakes\nbuilders = "),
		"inherited NIX_CONFIG must be preserved as a prefix, got: %q", got)
}

func TestPrint(t *testing.T) {
	val := "builders = x\nmax-jobs = 0"
	require.Equal(t, "set -gx NIX_CONFIG '"+val+"'", Print(val, true))
	require.Equal(t, "export NIX_CONFIG='"+val+"'", Print(val, false))
	require.Equal(t, "set -e NIX_CONFIG", PrintClear(true))
	require.Equal(t, "unset NIX_CONFIG", PrintClear(false))
}

func TestPrintQuotingEscapes(t *testing.T) {
	// A value containing a single quote must stay a valid single-quoted literal.
	require.Equal(t, `export NIX_CONFIG='a'\''b'`, Print("a'b", false))
	require.Equal(t, `set -gx NIX_CONFIG 'a\'b\\c'`, Print(`a'b\c`, true))
}

func TestResolveUnknown(t *testing.T) {
	r := Registry{devLDN}
	_, err := r.Resolve([]string{"dev.ldn"})
	require.NoError(t, err, "known name should resolve")
	_, err = r.Resolve([]string{"nope"})
	require.ErrorContains(t, err, "unknown builder")
}

func TestSelectPrefersFastestReachablePerHost(t *testing.T) {
	lan := Builder{Name: "dev.ldn", Host: "dev.ldn", HostName: "lan", SpeedFactor: 4}
	ts := Builder{Name: "dev-ldn", Host: "dev.ldn", HostName: "ts", SpeedFactor: 2}
	other := Builder{Name: "kratail2", Host: "kratail2", HostName: "k", SpeedFactor: 5}
	r := Registry{lan, ts, other}

	// Both dev.ldn endpoints reachable -> pick the faster LAN; kratail2 down -> dropped.
	got := r.Select(func(h string) bool { return h != "k" })
	require.Equal(t, []string{"dev.ldn"}, names(got))

	// LAN down -> fall back to tailnet endpoint of the same host.
	got = r.Select(func(h string) bool { return h == "ts" })
	require.Equal(t, []string{"dev-ldn"}, names(got))
}

// TestSSHAddr pins the Reachable dial-address derivation: an explicit port in
// HostName wins, everything else defaults to 22.
func TestSSHAddr(t *testing.T) {
	cases := []struct{ in, want string }{
		{"dev.ldn.fap.no", "dev.ldn.fap.no:22"},
		{"dev.ldn.fap.no:2222", "dev.ldn.fap.no:2222"},
		{"10.0.0.1", "10.0.0.1:22"},
		{"fe80::1", "[fe80::1]:22"},
		{"[::1]:2222", "[::1]:2222"},
	}
	for _, c := range cases {
		require.Equal(t, c.want, sshAddr(c.in), "sshAddr(%q)", c.in)
	}
}

// TestJSONRoundTrip pins the shape builtins.toJSON emits from
// common/rnb-builders.nix so the Nix-rendered config stays decodable.
func TestJSONRoundTrip(t *testing.T) {
	raw := `[
	  {"name":"dev.ldn","host":"dev.ldn","hostName":"dev.ldn.fap.no",
	   "systems":["x86_64-linux","aarch64-linux"],"sshUser":"root",
	   "sshKey":"/Users/kradalby/.ssh/id_ed25519","maxJobs":4,"speedFactor":4,
	   "supportedFeatures":["big-parallel","kvm","nixos-test"],
	   "publicHostKey":"c3NoLWtleQ==","hasRosetta":false}
	]`
	var r Registry
	require.NoError(t, json.Unmarshal([]byte(raw), &r))
	require.Len(t, r, 1)
	want := "ssh-ng://root@dev.ldn.fap.no x86_64-linux,aarch64-linux /Users/kradalby/.ssh/id_ed25519 4 4 big-parallel,kvm,nixos-test - c3NoLWtleQ=="
	require.Equal(t, want, r[0].Spec())
}

func names(bs []Builder) []string {
	out := make([]string, len(bs))
	for i, b := range bs {
		out[i] = b.Name
	}
	return out
}
