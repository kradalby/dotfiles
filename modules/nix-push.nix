{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.services.nix-push;
  queueDir = "/var/lib/nix-push";
  nix-push = pkgs.callPackage ../pkgs/nix-push {};

  pushHook = pkgs.writeShellScript "nix-push-hook" ''
    set -eu
    set -f
    export IFS=' '
    if [ -n "''${OUT_PATHS:-}" ]; then
      (
        flock 200
        echo $OUT_PATHS >> ${queueDir}/queue
      ) 200>${queueDir}/lock
    fi
  '';
in {
  options.services.nix-push = {
    enable = lib.mkEnableOption "Auto-push nix store paths to remote cache";
    target = lib.mkOption {
      type = lib.types.str;
      default = "ssh-ng://root@10.65.0.29";
      description = "Nix store URL to push to";
    };
    sshKeyFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to SSH private key for authenticating to the cache";
    };
  };

  config = lib.mkIf cfg.enable {
    nix.settings.post-build-hook = pushHook;

    systemd.tmpfiles.rules = [
      "d ${queueDir} 0755 root root -"
    ];

    systemd.services.nix-push = {
      description = "Push nix store paths to remote cache";
      wantedBy = ["multi-user.target"];
      path = [pkgs.nix pkgs.openssh];
      serviceConfig = {
        ExecStart = "${nix-push}/bin/nix-push --queue-dir ${queueDir} --target '${cfg.target}' --ssh-key ${cfg.sshKeyFile}";
        Restart = "always";
        RestartSec = "30s";
      };
    };
  };
}
