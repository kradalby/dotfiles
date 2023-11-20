{
  buildGoModule,
  fetchFromGitHub,
  lib,
  installShellFiles,
}:
buildGoModule rec {
  pname = "gitutil";
  version = "1625713288102f8642c0619f12fc83ad609bf71b";

  src = fetchFromGitHub {
    owner = "bradfitz";
    repo = "gitutil";
    rev = "${version}";
    sha256 = "sha256-cR5qfQcRfHiX6A1eIgBHIzeqTZXjUw1FuJlF2RVaels=";
  };

  subPackages = ["git-cleanup" "git-allgoupdate" "git-clpatch"];

  vendorHash = "sha256-pQpattmS9VmO3ZIQUFn66az8GSmB4IvYhTTCFn6SUmo=";

  doCheck = false;

  nativeBuildInputs = [installShellFiles];
}
