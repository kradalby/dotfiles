{ pkgs }:
pkgs.writeShellApplication {
  name = "codex-plugin-install";
  runtimeInputs = [
    pkgs.master.codex
    pkgs.jq
  ];
  text = builtins.readFile ./codex-plugin-install.sh;
}
