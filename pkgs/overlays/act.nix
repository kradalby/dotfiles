{ buildGoModule, fetchFromGitHub, lib, installShellFiles }:
buildGoModule rec {
  pname = "act";
  version = "master";

  src = fetchFromGitHub {
    owner = "nektos";
    repo = "act";
    rev = "3db3c737230adc457e08a8d60b34458977d01e5c";
    sha256 = "sha256-2S0DEXXluKg1n8TL71f5CDWrRYSSM62A+JrfbsQMUHA=";
  };

  vendorSha256 = "sha256-qaAWV0K22Rp8RlNdjUP5zPKk2Sl+dQIwfMPlSb72EBs=";

  doCheck = false;

  nativeBuildInputs = [ installShellFiles ];
}
