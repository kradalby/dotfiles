{ pkgs }:
pkgs.runCommand "disk-cleanup-test"
  {
    nativeBuildInputs = with pkgs; [
      bash
      coreutils
      findutils
      gnused
      (import ../../pkgs/scripts/disk-cleanup.nix { inherit pkgs; })
    ];
  }
  ''
    bash ${../../pkgs/scripts/disk-cleanup-test.sh} ${../../pkgs/scripts/disk-cleanup.sh}
    touch "$out"
  ''
