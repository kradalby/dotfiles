{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "codex-nix-dev-env-hook";

  # Manages its own control flow, including ignored events and load failures.
  bashOptions = [ ];

  runtimeInputs = with pkgs; [
    jq
    direnv
    nix
    coreutils
  ];

  text = builtins.readFile ./codex-nix-dev-env-hook.sh;
}
