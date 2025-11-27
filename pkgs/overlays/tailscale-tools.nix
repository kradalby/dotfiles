{
  buildGoModule,
  fetchFromGitHub,
  lib,
  installShellFiles,
}: let
  versions = import ../../metadata/versions.nix;
in
buildGoModule rec {
  name = "tailscale-tools";
  # NOTE: manual update required
  # https://github.com/tailscale/tailscale/releases
  # Keeping at previous version - v1.90.4 requires Go 1.25.3 which is not available yet
  version = versions.pkgs.overlays.tailscaleTools;

  src = fetchFromGitHub {
    owner = "tailscale";
    repo = "tailscale";
    rev = "${version}";
    sha256 = "sha256-gCYZlxE0eswyuEEoIIM7elNT8gNu6aISY/bh2NFWRPU=";
  };
  vendorHash = "sha256-GWzaAtZW7puyX62jsZaFiyvCUh7X/D4Ea9RDzyxAAiI=";
  subPackages = [
    "cmd/proxy-to-grafana"
    "cmd/nginx-auth"
    "cmd/nardump"
  ];
}
