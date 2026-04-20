{lib, ...}: {
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

  my.packages = {
    nix.enable = false;
    python.enable = false;
    infra.enable = false;
    media.enable = false;
    ai.opencode = true;
  };
}
