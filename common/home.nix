{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: {
  environment.homeBinInPath = true;
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
    sharedModules = [inputs.nix-index-database.homeModules.nix-index];
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
