{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
{
  environment.homeBinInPath = true;
  # HM's activation service is a bare oneshot, so switch-to-configuration
  # (colmena/nixos-rebuild) won't re-run it on a live switch -- it only fires
  # at boot via multi-user.target, leaving user services on the old generation
  # (i.e. new versions never adopted on deploy). RemainAfterExit keeps it
  # "active (exited)" so switch reconciles it on every change.
  systemd.services.home-manager-kradalby.serviceConfig.RemainAfterExit = lib.mkForce true;

  home-manager = {
    verbose = true;
    # Force-overwrite backups instead of backupFileExtension, which aborts
    # activation when a stale *.hm_bak~ already exists (apps like go/claude
    # rewrite HM-managed config, so the collision recurs every switch). A
    # failed activation freezes user services on the old generation, so new
    # package versions are never adopted.
    backupCommand = "${pkgs.writeShellScript "hm-backup" ''
      exec ${pkgs.coreutils}/bin/mv -f "$1" "$1.hm_bak~"
    ''}";
    useGlobalPkgs = true;
    useUserPackages = true;
    sharedModules = [ inputs.nix-index-database.homeModules.nix-index ];
    users = {
      kradalby = {
        imports = [
          ../home
        ];
        programs.git = {
          settings = {
            user = {
              signingkey = lib.mkForce "/home/kradalby/.ssh/id_ed25519.pub";
            };
          };
        };
      };
      # root = {
      #   imports = [
      #     ../home
      #   ];
      # };
    };
  };
}
