# This file contains a modified copy of the official Tailscale module
# which sets up a second tailscale service (tailscale2) which only
# runs in userspace mode. In my case, it is intended to run
# a userspace tailscale with SSH that is connected to my Headscale
# infrastructure. This is an experiment.
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.tailscale2;
in {
  meta.maintainers = with maintainers; [kradalby];

  options.services.tailscale2 = {
    enable = mkEnableOption (lib.mdDoc "Second Tailscale daemon that only runs in userspace");

    port = mkOption {
      type = types.port;
      default = 41642;
      description = lib.mdDoc "The port to listen on for tunnel traffic (0=autoselect).";
    };

    permitCertUid = mkOption {
      type = types.nullOr types.nonEmptyStr;
      default = null;
      description = lib.mdDoc "Username or user ID of the user allowed to to fetch Tailscale TLS certificates for the node.";
    };

    package = lib.mkPackageOptionMD pkgs "tailscale" {};

    authKeyFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = "/run/secrets/tailscale2_key";
      description = lib.mdDoc ''
        A file containing the auth key.
      '';
    };

    socketFile = mkOption {
      type = types.nullOr types.path;
      default = "/var/run/tailscale2/tailscaled2.sock";
      example = "/var/run/tailscale2/tailscaled2.sock";
      description = lib.mdDoc ''
        socket to control tailscaled2
      '';
    };

    stateDir = mkOption {
      type = types.nullOr types.path;
      default = "/var/lib/tailscale2";
      example = "/var/lib/tailscale2";
      description = lib.mdDoc ''
        state directory for tailscaled2
      '';
    };

    extraUpFlags = mkOption {
      description = lib.mdDoc "Extra flags to pass to {command}`tailscale up`.";
      type = types.listOf types.str;
      default = [];
      example = ["--ssh"];
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      cfg.package
      (pkgs.writeShellScriptBin "tailscale2" ''
        ${cfg.package}/bin/tailscale --socket=${cfg.socketFile} "$@"
      '')
    ]; # for the CLI
    systemd.packages = [cfg.package];
    systemd.services.tailscaled2 = {
      wantedBy = ["multi-user.target"];

      preStart = "${cfg.package}/bin/tailscaled --cleanup --statedir ${cfg.stateDir} --socket ${cfg.socketFile}";
      postStart = "${cfg.package}/bin/tailscaled --cleanup --statedir ${cfg.stateDir} --socket ${cfg.socketFile}";
      script = ''
        ${cfg.package}/bin/tailscaled --statedir=${cfg.stateDir} --socket=${cfg.socketFile} --tun=userspace-networking --port=${toString cfg.port}
      '';

      serviceConfig = {
        RuntimeDirectory = "tailscale2";
        RuntimeDirectoryMode = "0755";
        StateDirectory = "tailscale2";
        StateDirectoryMode = "0700";
        CacheDirectory = "tailscale2";
        CacheDirectoryMode = "0750";

        # This should be notify
        Type = "exec";
      };
      # Restart tailscaled2 with a single `systemctl restart` at the
      # end of activation, rather than a `stop` followed by a later
      # `start`. Activation over Tailscale can hang for tens of
      # seconds in the stop+start setup, if the activation script has
      # a significant delay between the stop and start phases
      # (e.g. script blocked on another unit with a slow shutdown).
      #
      # Tailscale is aware of the correctness tradeoff involved, and
      # already makes its upstream systemd unit robust against unit
      # version mismatches on restart for compatibility with other
      # linux distros.
      stopIfChanged = false;
    };

    systemd.services.tailscaled2-autoconnect = mkIf (cfg.authKeyFile != null) {
      after = ["tailscaled2.service"];
      wants = ["tailscaled2.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
      };
      script = ''
        status=$(${config.systemd.package}/bin/systemctl show -P StatusText tailscaled2.service)
        if [[ $status != Connected* ]]; then
          ${cfg.package}/bin/tailscale --socket ${cfg.socketFile} up --auth-key 'file:${cfg.authKeyFile}'  ${escapeShellArgs cfg.extraUpFlags}
        fi
      '';
    };
  };
}
