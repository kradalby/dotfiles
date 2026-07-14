{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "ac";

  runtimeInputs = with pkgs; [
    herdr
    git
    jq
    coreutils
    gnused
  ];

  text = builtins.readFile ./ac.sh;
}
