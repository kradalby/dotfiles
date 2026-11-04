{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "wt";

  runtimeInputs = with pkgs; [
    coreutils
    direnv
    gawk
    gh
    git
  ];

  text = builtins.readFile ./wt.sh;
}
