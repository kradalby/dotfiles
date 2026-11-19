{ ... }: {
  # ac-web: auth-less web UI to spawn `ac` coding-agent sessions from the phone.
  # Binds to the host's tailnet IP (see pkgs/ac-web/main.go), so only the tailnet
  # can reach it — no auth. Sessions it spawns are rex sessions.
  home-manager.users.kradalby =
    {
      config,
      pkgs,
      ...
    }:
    {
      systemd.user.services.ac-web = {
        Unit = {
          Description = "ac-web: spawn ac coding-agent sessions from the phone";
          # No network-online ordering: a user unit can't order on the system
          # target, and it's moot anyway — ac-web retries `tailscale ip -4` in-process
          # (main.go tailnetAddr) until the tailnet address shows up.
        };
        Service = {
          ExecStart = "${pkgs.ac-web}/bin/ac-web";
          Restart = "always";
          RestartSec = 15;
          # `ac spawn` autostarts the rex server when none runs, which puts it
          # and every agent in this unit's cgroup. A restart must not kill them.
          KillMode = "process";
          # Profile bin has `ac` (which bundles rex); system bin has git/tailscale
          # that ac and ac-web shell out to.
          Environment = [
            "PATH=${config.home.profileDirectory}/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin"
            "HOME=${config.home.homeDirectory}"
          ];
        };
        Install.WantedBy = [ "default.target" ];
      };
    };
}
