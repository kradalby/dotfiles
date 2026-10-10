{ pkgs }:
pkgs.runCommand "tmp-cleanup-test"
  {
    nativeBuildInputs = with pkgs; [
      bash
      coreutils
      findutils
      gawk
      gnused
      (import ../../pkgs/scripts/tmp-cleanup.nix { inherit pkgs; })
    ];
  }
  ''
    bash ${../../pkgs/scripts/tmp-cleanup-test.sh} ${../../pkgs/scripts/tmp-cleanup.sh}
    touch "$out"
  ''
