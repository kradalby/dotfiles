{
  src,
  version,
  buildGoModule,
  lib,
  installShellFiles,
}:
buildGoModule rec {
  pname = "tailscale-tools";
  inherit src version;

  vendorHash = "sha256-CEZxW9kZUIjI3frTZOEKssYJz3Uo58+YdLm8iEjTeMo=";
  subPackages = [
    "cmd/proxy-to-grafana"
    "cmd/nginx-auth"
    "cmd/nardump"
  ];
}
