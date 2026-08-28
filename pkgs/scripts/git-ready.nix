{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "git-ready";

  runtimeInputs = with pkgs; [
    git
    gawk
    coreutils
  ];

  text = builtins.readFile ./git-ready.sh;
}
