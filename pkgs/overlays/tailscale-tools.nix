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
    hash = "sha256-sJh3oXFarS1s+flMfm4ZAE+0ZSwp8F3Rib76+qBFVIw=";
  };
  vendorHash = "sha256-RvaouD88naVNOPJBVcqMaAn+ovjXI4g83ShCdRiR5/Q=";
  subPackages = [
    "cmd/proxy-to-grafana"
    "cmd/nginx-auth"
    "cmd/nardump"
  ];
}
