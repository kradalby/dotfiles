{
  config,
  pkgs,
  lib,
  claudeCodeLib,
  ...
}: let
  inherit (claudeCodeLib) resolvePath mkArgs enabled;

  linuxPath = "${config.home.profileDirectory}/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin";

  mkSystemdUnit = name: ic: {
    Unit = {
      Description = "claude remote-control: ${name}";
      After = ["network-online.target"];
      Wants = ["network-online.target"];
      # Cap restart bursts so a wedged service doesn't hammer the bridge.
      StartLimitIntervalSec = 300;
      StartLimitBurst = 5;
    };
    Service = {
      Type = "simple";
      WorkingDirectory = resolvePath ic.path;
      ExecStart = lib.escapeShellArgs (mkArgs name ic);
      Restart = "on-failure";
      RestartSec = 15;
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
    Install.WantedBy = ["default.target"];
  };
in {
  config = lib.mkIf (pkgs.stdenv.isLinux && enabled != {}) {
    systemd.user.services =
      lib.mapAttrs' (n: ic: lib.nameValuePair "claude-code-${n}" (mkSystemdUnit n ic)) enabled;
  };
}
