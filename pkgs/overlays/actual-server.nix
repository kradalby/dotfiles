{pkgs, ...}: let
  src = pkgs.fetchFromGitHub {
    owner = "actualbudget";
    repo = "actual-server";
    rev = "v23.9.0";
    sha256 = "";
  };

  actualDeps = pkgs.yarn2nix-moretea.mkYarnPackage {
    name = "actualServerDeps";
    inherit src;
  };
in
  pkgs.stdenv.mkDerivation {
    name = "actual-server";
    inherit src;

    buildInputs = with pkgs; [
      actualDeps

      yarn
    ];

    postUnpack = ''
      export HOME="$TMP"
    '';

    patchPhase = ''
      ln -fs ${actualDeps}/libexec/actual/node_modules .
    '';
  }
