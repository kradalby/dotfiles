{lib, ...}: {
  imports = [
    ../../home
  ];

  home.username = "kradalby";
  home.homeDirectory = "/home/kradalby";

  # Work machine git config (same pattern as kratail2)
  programs.git.settings.user.email = lib.mkForce "kristoffer@tailscale.com";

  my.packages = {
    nix.enable = false;
    python.enable = false;
    elm.enable = false;
    infra.enable = false;
    media.enable = false;
    ai.opencode = false;
  };
}
