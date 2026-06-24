{pkgs, ...}:
pkgs.writeShellApplication {
  name = "codex-nix-dev-env-hook";

  # Manages its own control flow (non-zero exits are intentional passthrough).
  bashOptions = [];

  runtimeInputs = with pkgs; [
    jq
    direnv
    nix
    coreutils # base64, printf
  ];

  text = builtins.readFile ./codex-nix-dev-env-hook.sh;
}
