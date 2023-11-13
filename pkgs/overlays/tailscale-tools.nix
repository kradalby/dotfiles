{
  buildGoModule,
  fetchFromGitHub,
  lib,
  installShellFiles,
}:
buildGoModule rec {
  name = "tailscale-tools";
  version = "1.52.1";

  src = fetchFromGitHub {
    owner = "tailscale";
    repo = "tailscale";
    rev = "v${version}";
    sha256 = "sha256-hscKV4jhJ+tqgTFuOEThABpu8iqK3+av7+DcuSmZwQ4=";
  };
  vendorSha256 = "sha256-WGZkpffwe4I8FewdBHXGaLbKQP/kHr7UF2lCXBTcNb4=";
  CGO_ENABLED = 0;
  subPackages = ["cmd/proxy-to-grafana" "cmd/nginx-auth"];
  doCheck = false;
}
