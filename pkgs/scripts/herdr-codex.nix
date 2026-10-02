{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "herdr-codex";
  runtimeInputs = with pkgs; [
    herdr
    jq
  ];
  text = builtins.readFile ./herdr-codex.sh;
}
