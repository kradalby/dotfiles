{...}: {
  # ac-web: auth-less web UI to spawn `ac` coding-agent sessions from the phone.
  # Binds to the host's tailnet IP (see pkgs/ac-web/main.go), so only the tailnet
  # can reach it — no auth. Sessions it spawns are ordinary tmux servers in the
  # shared /tmp, so an interactive `ac` (over ssh) attaches to them later; hence
  # NO PrivateTmp here (unlike services.claude-code, which isolates its /tmp).
  home-manager.users.kradalby = {
    config,
    pkgs,
    ...
  }: {
    systemd.user.services.ac-web = {
      Unit = {
        Description = "ac-web: spawn ac coding-agent sessions from the phone";
        After = ["network-online.target"];
        Wants = ["network-online.target"];
      };
      Service = {
        ExecStart = "${pkgs.ac-web}/bin/ac-web";
        Restart = "always";
        RestartSec = 15;
        # KillMode=process so restarting ac-web does not tear down the detached
        # tmux servers it spawned (they live in this unit's cgroup).
        KillMode = "process";
        # Same PATH as modules/claude-code: profile bin has `ac`; system bin has
        # tmux/git/tailscale that ac and ac-web shell out to.
        Environment = [
          "PATH=${config.home.profileDirectory}/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin"
          "HOME=${config.home.homeDirectory}"
        ];
      };
      Install.WantedBy = ["default.target"];
    };
  };
}
