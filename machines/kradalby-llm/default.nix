{
  lib,
  config,
  ...
}: let
  baseSettings = builtins.fromJSON (builtins.readFile ../../rc/claude/settings.json);
  machineSettings =
    builtins.removeAttrs baseSettings ["apiKeyHelper"]
    // {
      env =
        baseSettings.env
        // {
          ANTHROPIC_API_KEY = "-";
          ANTHROPIC_BASE_URL = "http://ai.corp.ts.net";
          PATH = "${config.home.profileDirectory}/bin:/nix/var/nix/profiles/default/bin:/usr/local/bin:/usr/bin:/bin";
        };
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

  # Use corp AI proxy instead of the default plugin-based auth
  home.file.".config/opencode/opencode.json" = lib.mkForce {
    source = ./opencode.json;
  };

  # Override claude settings to use corp AI proxy
  home.file.".claude/settings.json" = lib.mkForce {
    text = builtins.toJSON machineSettings;
  };

  my.packages = {
    nix.enable = false;
    python.enable = false;
    infra.enable = false;
    media.enable = false;
    ai.opencode = true;
  };
}
