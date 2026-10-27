{
  buildGoModule,
  fetchFromGitHub,
  lib,
  installShellFiles,
}:
let
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
    hash = "sha256-vMkNFJSwf/UPCUnMZiFd+cfOspdvHMU4GPs/LAqxib0=";
  };
  vendorHash = "sha256-VxuDS8QKZ82W/MOlfng0+ZCPSPl5KnK3FYW1puDiNe4=";
  subPackages = [
    "cmd/proxy-to-grafana"
    "cmd/nginx-auth"
    "cmd/nardump"
  ];
}
