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
    hash = "sha256-VnAEfY8W+2QPnQLvVFJA7/XyvSnppSdRvgAOgpmRFGM=";
  };
  vendorHash = "sha256-rhuWEEN+CtumVxOw6Dy/IRxWIrZ2x6RJb6ULYwXCQc4=";
  subPackages = [
    "cmd/proxy-to-grafana"
    "cmd/nginx-auth"
    "cmd/nardump"
  ];
}
