{
  buildGoModule,
  fetchFromGitHub,
}: let
  versions = import ../../metadata/versions.nix;
in
buildGoModule rec {
  name = "tailscale-restic-proxy";
  # NOTE: manual update required
  # https://github.com/JonaEnz/tailscale-restic-proxy/commits/main/
  version = versions.pkgs.overlays.tailscaleResticProxy;

  src = fetchFromGitHub {
    owner = "JonaEnz";
    repo = "tailscale-restic-proxy";
    rev = "${version}";
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };
  vendorHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  CGO_ENABLED = 0;
  subPackages = ["cmd/ts-restic-proxy"];
}
