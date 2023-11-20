{
  buildGoModule,
  fetchFromGitHub,
  lib,
  installShellFiles,
}:
buildGoModule rec {
  pname = "act";
  version = "0.2.53";

  src = fetchFromGitHub {
    owner = "nektos";
    repo = "act";
    rev = "v${version}";
    sha256 = "sha256-p2ujmHWIBUcH5UpHHO72ddqSb1C0gWAyKUIT9E6Oyxk=";
  };

  vendorHash = "sha256-W50NodoaKY7s4x7Goyvydxd5Q2lz9m9pFwgcQ9wRGVM=";

  doCheck = false;

  nativeBuildInputs = [installShellFiles];
}
