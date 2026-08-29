{
  buildGoModule,
  fetchFromGitHub,
}:
let
  versions = import ../../metadata/versions.nix;
in
buildGoModule rec {
  name = "setec";
  # NOTE: manual update required
  # https://github.com/tailscale/setec/commits/main/
  version = versions.pkgs.overlays.setec;

  src = fetchFromGitHub {
    owner = "tailscale";
    repo = "setec";
    rev = "${version}";
    sha256 = "sha256-MUfggP95oT8c+x6ZKVADXLHucj/p0qKiVbH9oERTzgw=";
  };
  vendorHash = "sha256-OWW4+k/+tpAn5N4w0/5peEpGwbIHVyXp2m857JVKuFs=";
  env = {
    CGO_ENABLED = 0;
  };
  subPackages = [ "cmd/setec" ];
}
