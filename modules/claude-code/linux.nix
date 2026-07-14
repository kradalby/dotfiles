{
  config,
  pkgs,
  lib,
  claudeCodeLib,
  ...
}:
let
  inherit (claudeCodeLib) resolvePath mkArgs enabled;

  linuxPath = "${config.home.profileDirectory}/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin";

  # Self-contained: bundles journalctl/systemctl plus the text utils it needs,
  # so the watchdog works regardless of what the login session exports.
  healthcheck = import ./healthcheck.nix { inherit pkgs lib; };
  instanceNames = lib.escapeShellArgs (lib.attrNames enabled);

  mkSystemdUnit = name: ic: {
    Unit = {
      Description = "claude remote-control: ${name}";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
      # Cap restart bursts so a wedged service doesn't hammer the bridge.
      StartLimitIntervalSec = 300;
      StartLimitBurst = 5;
    };
    Service = {
      Type = "simple";
      WorkingDirectory = resolvePath ic.path;
      ExecStart = lib.escapeShellArgs (mkArgs name ic);
      # Always restart: a clean exit (graceful shutdown, exit 0) should still
      # come back. StartLimitBurst below caps a genuine crash loop.
      Restart = "always";
      RestartSec = 15;
      # Graceful over forced: SIGTERM lets claude preserve its environment so a
      # restart resumes the same builder instead of orphaning a new one. mixed
      # (SIGTERM to main, SIGKILL to stragglers at timeout) lets the main process
      # orchestrate its own teardown; TimeoutStopSec gives it room to finish.
      KillSignal = "SIGTERM";
      KillMode = "mixed";
      TimeoutStopSec = 30;
      # Per-unit /tmp namespace. Isolates /tmp/claude-<uid>/ from interactive
      # shells and from sibling services, so a stray `tmp-cleanup -y` in a
      # user terminal can never reach this service's bridge dir.
      PrivateTmp = true;
      Environment = [
        "PATH=${linuxPath}"
        "HOME=${config.home.homeDirectory}"
      ];
    };
    Install.WantedBy = [ "default.target" ];
  };
in
{
  config = lib.mkIf (pkgs.stdenv.isLinux && enabled != { }) {
    systemd.user.services =
      (lib.mapAttrs' (n: ic: lib.nameValuePair "claude-code-${n}" (mkSystemdUnit n ic)) enabled)
      // {
        # Restart=on-failure only catches exits. This catches the alive-but-stuck
        # case (bridge disconnect / lost login) that otherwise sits there
        # "failing to schedule" forever.
        claude-code-health = {
          Unit.Description = "claude remote-control watchdog";
          Service = {
            Type = "oneshot";
            ExecStart = "${healthcheck}/bin/claude-code-health ${instanceNames}";
          };
        };
      };

    systemd.user.timers.claude-code-health = {
      Unit.Description = "claude remote-control watchdog timer";
      Timer = {
        OnBootSec = "2min";
        OnUnitActiveSec = "2min";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
