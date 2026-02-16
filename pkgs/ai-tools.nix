# AI CLI tools for home-manager
{pkgs, ...}: {
  home.packages = with pkgs.master; [
    codex
    gemini-cli
    claude-code
    claude-code-acp
    claude-monitor
    pkgs.opencode
  ];
}
