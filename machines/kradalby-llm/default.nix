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

  # Use HTTPS for GitHub on this machine (SSH egress not available).
  # mkForce replaces the SSH rewrite from home/git.nix entirely so the
  # "gh:" alias and any SSH github remotes resolve to HTTPS.
  programs.git.settings.url = lib.mkForce {
    "https://github.com/" = {
      insteadOf = ["gh:" "git@github.com:" "ssh://git@github.com/"];
      pushInsteadOf = ["gh:" "git@github.com:" "ssh://git@github.com/"];
    };
  };
  programs.gh.settings.git_protocol = lib.mkForce "https";

  # Override AI tool configs to use corp proxy
  my.mutableJson.opencode.value = lib.mkForce opencodeSettings;
  my.mutableJson.claude-settings.value = lib.mkForce claudeSettings;

  my.packages = {
    nix.enable = false;
    python.enable = false;
    infra.enable = false;
    media.enable = false;
    ai.opencode = true;
  };
}
