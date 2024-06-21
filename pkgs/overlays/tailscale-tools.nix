{
  buildGoModule,
  fetchFromGitHub,
  lib,
  installShellFiles,
}:
buildGoModule rec {
  name = "tailscale-tools";
  # NOTE: manual update required
  # https://github.com/tailscale/tailscale/releases
  version = "fe661281001b5d57fa603d43b2be69222d896e04";

  src = fetchFromGitHub {
    owner = "tailscale";
    repo = "tailscale";
    rev = "${version}";
    sha256 = "sha256-oij826VlNiXNwE9cDgk/oic6YRvKk/yWoi0DVAktk0o=";
  };
  vendorHash = "sha256-ye8puuEDd/CRSy/AHrtLdKVxVASJAdpt6bW3jU2OUvw=";
  CGO_ENABLED = 0;
  subPackages = ["cmd/proxy-to-grafana" "cmd/nginx-auth" "cmd/nardump"];
  doCheck = false;
}
