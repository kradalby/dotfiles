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
      sha256 = "sha256-id7DX/uCSqjEMYLVKGaTiJ/GIosuVjfPT5SSbrcwYwo=";
    };

    subPackages = ["git-cleanup" "git-allgoupdate" "git-clpatch"];

    vendorHash = null;

    nativeBuildInputs = [installShellFiles];
  }
