{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.services.nix-push-darwin;
  queueDir = "/var/lib/nix-push";
  nix-push = pkgs.callPackage ../pkgs/nix-push {};

  pushHook = pkgs.writeShellScript "nix-push-hook" ''
    set -eu
    set -f
    export IFS=' '
    if [ -n "''${OUT_PATHS:-}" ]; then
      (
        ${pkgs.flock}/bin/flock 200
        echo $OUT_PATHS >> ${queueDir}/queue
      ) 200>${queueDir}/lock
    fi
  '';
in {
  options.services.nix-push-darwin = {
    enable = lib.mkEnableOption "Auto-push nix store paths to remote cache (Darwin)";
    target = lib.mkOption {
      type = lib.types.str;
      default = "ssh-ng://root@10.65.0.29";
      description = "Nix store URL to push to";
    };
    sshKeyFile = lib.mkOption {
      type = lib.types.str;
      default = "/Users/kradalby/.ssh/id_ed25519";
      description = "Path to SSH private key for authenticating to the cache";
    };
  };

  config = lib.mkIf cfg.enable {
    nix.settings.post-build-hook = pushHook;

    system.activationScripts.postActivation.text = ''
      mkdir -p ${queueDir}
    '';

    launchd.daemons.nix-push = {
      command = "${nix-push}/bin/nix-push --queue-dir ${queueDir} --target '${cfg.target}' --ssh-key ${cfg.sshKeyFile}";
      path = [config.nix.package pkgs.openssh];
      serviceConfig = {
        RunAtLoad = true;
        KeepAlive = true;
        StandardOutPath = "/var/log/nix-push.log";
        StandardErrorPath = "/var/log/nix-push-error.log";
      };
    };
  };
}
