{pkgs, ...}: let
  src = pkgs.fetchFromGitHub {
    owner = "actualbudget";
    repo = "actual";
    rev = "v23.9.0";
    sha256 = "";
  };

  actualDeps = pkgs.yarn2nix-moretea.mkYarnPackage {
    name = "actualDeps";
    inherit src;
  };
in
  pkgs.stdenv.mkDerivation {
    name = "actual-browser";
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

    installPhase = ''
      mkdir -p $out

    '';
  }
