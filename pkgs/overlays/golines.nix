{ buildGoModule, fetchFromGitHub, lib, installShellFiles }:
buildGoModule rec {
  pname = "golines";
  version = "0.9.0";

  src = fetchFromGitHub {
    owner = "segmentio";
    repo = "golines";
    rev = "v${version}";
    sha256 = "sha256-BUXEg+4r9L/gqe4DhTlhN55P3jWt7ZyWFQycO6QePrw=";
  };

  vendorSha256 = "sha256-sEzWUeVk5GB0H41wrp12P8sBWRjg0FHUX6ABDEEBqK8=";

  doCheck = false;

  nativeBuildInputs = [ installShellFiles ];
}
