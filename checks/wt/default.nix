{ pkgs }:
pkgs.runCommand "wt-test"
  {
    nativeBuildInputs = with pkgs; [
      bash
      git
      (import ../../pkgs/scripts/wt.nix { inherit pkgs; })
    ];
  }
  ''
    bash ${../../pkgs/scripts/wt-test.sh}
    touch "$out"
  ''
