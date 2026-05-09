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
    };
    Service = {
      Type = "simple";
      WorkingDirectory = resolvePath ic.path;
      ExecStart = lib.escapeShellArgs (mkArgs name ic);
      Restart = "on-failure";
      RestartSec = 15;
      KillSignal = "SIGTERM";
      TimeoutStopSec = 15;
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
