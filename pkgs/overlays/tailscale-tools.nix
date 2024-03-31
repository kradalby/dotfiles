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
  version = "1.56.1";

  src = fetchFromGitHub {
    owner = "tailscale";
    repo = "tailscale";
    rev = "v${version}";
    sha256 = "sha256-hscKV4jhJ+tqgTFuOEThABpu8iqK3+av7+DcuSmZwQ4=";
  };
  vendorHash = "sha256-WGZkpffwe4I8FewdBHXGaLbKQP/kHr7UF2lCXBTcNb4=";
  CGO_ENABLED = 0;
  subPackages = ["cmd/proxy-to-grafana" "cmd/nginx-auth" "cmd/nardump"];
  doCheck = false;
}
