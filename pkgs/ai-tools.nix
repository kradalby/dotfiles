# AI tools module for home-manager
# Import in machine configs and set options
{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.my.ai-tools;
in {
  options.my.ai-tools = {
    cli = lib.mkEnableOption "CLI AI tools (claude-code, codex, gemini-cli, etc.)";
    desktop = lib.mkEnableOption "Desktop AI tools (opencode-desktop)";
  };

  config = {
    home.packages =
      lib.optionals cfg.cli (with pkgs.master; [
        codex # OpenAI CLI
        gemini-cli # Gemini CLI
        claude-code # Anthropic CLI
        claude-code-acp # Bridge for Claude and Zed
        claude-monitor # Monitor for Claude
      ])
      ++ lib.optionals (cfg.desktop && pkgs.stdenv.isDarwin) (with pkgs.master; [
        opencode-desktop
      ]);
  };
}
