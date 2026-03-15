{
  buildGoModule,
  fetchFromGitHub,
  lib,
  installShellFiles,
}: let
  versions = import ../../metadata/versions.nix;
in
buildGoModule rec {
  pname = "tailscale-tools";
  # NOTE: manual update required
  # https://github.com/tailscale/tailscale/releases
  version = versions.pkgs.overlays.tailscaleTools;

  src = fetchFromGitHub {
    owner = "tailscale";
    repo = "tailscale";
    rev = "${version}";
    hash = "sha256-qjWVB8xWVgIVUgrf27F6hwiFIE+4ERXWeHv26ugg/x4=";
  };
  vendorHash = "sha256-WeMTOkERj4hvdg4yPaZ1gRgKnhRIBXX55kUVbX/k/xM=";
  subPackages = [
    "cmd/proxy-to-grafana"
    "cmd/nginx-auth"
    "cmd/nardump"
  ];
}
