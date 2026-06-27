package builders

import (
	"encoding/json"
	"strings"
	"testing"
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
			if got := tt.b.Spec(); got != tt.want {
				t.Errorf("Spec()\n got: %q\nwant: %q", got, tt.want)
			}
			if n := len(strings.Fields(tt.b.Spec())); n != 8 {
				t.Errorf("spec must have 8 fields, got %d: %q", n, tt.b.Spec())
			}
		})
	}
}

func TestNixConfigDefault(t *testing.T) {
	got := NixConfig([]Builder{devLDN}, false, "", "")
	want := "builders = " + devLDN.Spec() + "\nmax-jobs = 0\nbuilders-use-substitutes = true"
	if got != want {
		t.Errorf("default NixConfig\n got: %q\nwant: %q", got, want)
	}
}

func TestNixConfigMultipleBuildersJoin(t *testing.T) {
	b2 := Builder{Name: "b2", HostName: "h2", SSHUser: "root", Systems: []string{"x86_64-linux"}}
	got := NixConfig([]Builder{devLDN, b2}, false, "", "")
	wantBuilders := "builders = " + devLDN.Spec() + " ; " + b2.Spec()
	if !strings.HasPrefix(got, wantBuilders) {
		t.Errorf("builders should be ';'-joined\n got: %q\nwant prefix: %q", got, wantBuilders)
	}
}

func TestNixConfigMerge(t *testing.T) {
	got := NixConfig([]Builder{devLDN}, true, "@/etc/nix/machines", "")
	if !strings.HasPrefix(got, "builders = @/etc/nix/machines ; "+devLDN.Spec()) {
		t.Errorf("merge must prepend existing builders, got: %q", got)
	}
	if strings.Contains(got, "max-jobs = 0") {
		t.Errorf("merge must NOT force max-jobs=0 (keeps local building), got: %q", got)
	}
	if !strings.Contains(got, "builders-use-substitutes = true") {
		t.Errorf("merge should still set builders-use-substitutes, got: %q", got)
	}
}

func TestNixConfigExtendsBase(t *testing.T) {
	got := NixConfig([]Builder{devLDN}, false, "", "experimental-features = nix-command flakes")
	if !strings.HasPrefix(got, "experimental-features = nix-command flakes\nbuilders = ") {
		t.Errorf("inherited NIX_CONFIG must be preserved as a prefix, got: %q", got)
	}
}

func TestPrint(t *testing.T) {
	val := "builders = x\nmax-jobs = 0"
	if got, want := Print(val, true), "set -gx NIX_CONFIG '"+val+"'"; got != want {
		t.Errorf("fish print\n got: %q\nwant: %q", got, want)
	}
	if got, want := Print(val, false), "export NIX_CONFIG='"+val+"'"; got != want {
		t.Errorf("posix print\n got: %q\nwant: %q", got, want)
	}
	if got := PrintClear(true); got != "set -e NIX_CONFIG" {
		t.Errorf("fish clear: %q", got)
	}
	if got := PrintClear(false); got != "unset NIX_CONFIG" {
		t.Errorf("posix clear: %q", got)
	}
}

func TestPrintQuotingEscapes(t *testing.T) {
	// A value containing a single quote must stay a valid single-quoted literal.
	if got, want := Print("a'b", false), `export NIX_CONFIG='a'\''b'`; got != want {
		t.Errorf("posix escaping\n got: %q\nwant: %q", got, want)
	}
	if got, want := Print(`a'b\c`, true), `set -gx NIX_CONFIG 'a\'b\\c'`; got != want {
		t.Errorf("fish escaping\n got: %q\nwant: %q", got, want)
	}
}

func TestResolveUnknown(t *testing.T) {
	r := Registry{devLDN}
	if _, err := r.Resolve([]string{"dev.ldn"}); err != nil {
		t.Fatalf("known name should resolve: %v", err)
	}
	_, err := r.Resolve([]string{"nope"})
	if err == nil || !strings.Contains(err.Error(), "unknown builder") {
		t.Errorf("unknown name should error, got: %v", err)
	}
}

func TestSelectPrefersFastestReachablePerHost(t *testing.T) {
	lan := Builder{Name: "dev.ldn", Host: "dev.ldn", HostName: "lan", SpeedFactor: 4}
	ts := Builder{Name: "dev-ldn", Host: "dev.ldn", HostName: "ts", SpeedFactor: 2}
	other := Builder{Name: "kratail2", Host: "kratail2", HostName: "k", SpeedFactor: 5}
	r := Registry{lan, ts, other}

	// Both dev.ldn endpoints reachable -> pick the faster LAN; kratail2 down -> dropped.
	got := r.Select(func(h string) bool { return h != "k" })
	if len(got) != 1 || got[0].Name != "dev.ldn" {
		t.Fatalf("want only [dev.ldn], got %+v", names(got))
	}

	// LAN down -> fall back to tailnet endpoint of the same host.
	got = r.Select(func(h string) bool { return h == "ts" })
	if len(got) != 1 || got[0].Name != "dev-ldn" {
		t.Fatalf("want [dev-ldn] fallback, got %+v", names(got))
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
	if err := json.Unmarshal([]byte(raw), &r); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if len(r) != 1 {
		t.Fatalf("want 1 builder, got %d", len(r))
	}
	want := "ssh-ng://root@dev.ldn.fap.no x86_64-linux,aarch64-linux /Users/kradalby/.ssh/id_ed25519 4 4 big-parallel,kvm,nixos-test - c3NoLWtleQ=="
	if got := r[0].Spec(); got != want {
		t.Errorf("round-trip spec\n got: %q\nwant: %q", got, want)
	}
}

func names(bs []Builder) []string {
	out := make([]string, len(bs))
	for i, b := range bs {
		out[i] = b.Name
	}
	return out
}
