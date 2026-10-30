{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "tmp-cleanup";

  runtimeInputs = with pkgs; [
    coreutils
    findutils
    gawk
    git
    lsof
  ];

  text = builtins.readFile ./tmp-cleanup.sh;
}
