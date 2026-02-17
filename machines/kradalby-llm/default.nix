{lib, ...}: {
  imports = [
    ../../home
  ];

  home.username = "kradalby";
  home.homeDirectory = "/home/kradalby";

  # Work machine git config (same pattern as kratail2)
  programs.git.settings.user.email = lib.mkForce "kristoffer@tailscale.com";
}
