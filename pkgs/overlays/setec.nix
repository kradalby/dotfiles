{
  buildGoModule,
  fetchFromGitHub,
}: let
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
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };
  vendorHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  env = {
    CGO_ENABLED = 0;
  };
  subPackages = ["cmd/setec"];
}
