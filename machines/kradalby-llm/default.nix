{
  lib,
  config,
  ...
}: let
  aiConfig = import ../../home/ai.nix;

  # Corp AI proxy: strip login-based auth, inject proxy env.
  claudeSettings = lib.recursiveUpdate
    (builtins.removeAttrs aiConfig.claude ["apiKeyHelper"])
    {
      env = {
        ANTHROPIC_API_KEY = "-";
        ANTHROPIC_BASE_URL = "http://ai.corp.ts.net";
        PATH = "${config.home.profileDirectory}/bin:/nix/var/nix/profiles/default/bin:/usr/local/bin:/usr/bin:/bin";
      };
    };

  # Corp AI proxy: strip auth plugin, set provider endpoints.
  opencodeSettings = lib.recursiveUpdate
    (builtins.removeAttrs aiConfig.opencode ["plugin"])
    {
      provider = {
        anthropic.options = {
          baseURL = "https://ai.corp.ts.net/v1";
          apiKey = "-";
        };
        openai.options = {
          baseURL = "https://ai.corp.ts.net/v1";
          apiKey = "EMPTY";
        };
      };
      disabled_providers = ["opencode"];
    };
in {
  imports = [
    ../../home
    ./paseo.nix
  ];

  home.username = "ubuntu";
  home.homeDirectory = "/home/ubuntu";

  # Work machine git config (same pattern as kratail2)
  programs.git.settings.user.email = lib.mkForce "kristoffer@tailscale.com";

  # Override AI tool configs to use corp proxy
  home.file.".config/opencode/opencode.json" = lib.mkForce {
    text = builtins.toJSON opencodeSettings;
  };
  home.file.".claude/settings.json" = lib.mkForce {
    text = builtins.toJSON claudeSettings;
  };

  my.packages = {
    nix.enable = false;
    python.enable = false;
    infra.enable = false;
    media.enable = false;
    ai.opencode = true;
  };
}
