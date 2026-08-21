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
    hash = "sha256-vqNShvER4jT+8WJCcaSVboXPEP6S3QacmkC39tJkR4g=";
  };
  vendorHash = "sha256-amKkUPszyhG4N5ZtrB01swBACYq76raSS+SQRneLmwc=";
  subPackages = [
    "cmd/proxy-to-grafana"
    "cmd/nginx-auth"
    "cmd/nardump"
  ];
}
