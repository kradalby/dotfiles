{
  buildGoModule,
  fetchFromGitHub,
  lib,
  installShellFiles,
}:
buildGoModule rec {
  name = "setec";
  # NOTE: manual update required
  # https://github.com/tailscale/setec/commits/main/
  version = "1ab725da5f50038d66480ae017d85bccb514cde5";

  src = fetchFromGitHub {
    owner = "tailscale";
    repo = "setec";
    rev = "${version}";
    sha256 = "sha256-laf4lhMQ7VLYHTWlNBBWwGVeDx2DVRxvJiwDzLPEanc=";
  };
  vendorHash = "sha256-1/HevghGmpGesbqHNHerlhhzdjN1JxdMihJZeMDmQZI=";
  CGO_ENABLED = 0;
  subPackages = ["cmd/setec"];
  doCheck = false;
}
