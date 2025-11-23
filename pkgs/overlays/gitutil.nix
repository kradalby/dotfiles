{
  buildGoModule,
  fetchFromGitHub,
  lib,
  installShellFiles,
}: let
  versions = import ../../metadata/versions.nix;
in
buildGoModule rec {
  pname = "gitutil";
  version = versions.pkgs.overlays.gitutil;

  src = fetchFromGitHub {
    owner = "bradfitz";
    repo = "gitutil";
    rev = "${version}";
    sha256 = "sha256-cR5qfQcRfHiX6A1eIgBHIzeqTZXjUw1FuJlF2RVaels=";
  };

  subPackages = ["git-cleanup" "git-allgoupdate" "git-clpatch"];

  vendorHash = "sha256-pQpattmS9VmO3ZIQUFn66az8GSmB4IvYhTTCFn6SUmo=";

  nativeBuildInputs = [installShellFiles];
}
