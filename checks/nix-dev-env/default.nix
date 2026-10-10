{ pkgs }:
pkgs.runCommand "nix-dev-env-test"
  {
    nativeBuildInputs = with pkgs; [
      bash
      coreutils
      direnv
      gnugrep
      jq
      (import ../../pkgs/scripts/nix-dev-env.nix { inherit pkgs; })
    ];
  }
  ''
    bash ${../../pkgs/scripts/nix-dev-env-test.sh} ${../../pkgs/scripts/nix-dev-env.sh}
    touch "$out"
  ''
