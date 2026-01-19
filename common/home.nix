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
    backupFileExtension = "hm_bak~";
    useGlobalPkgs = true;
    useUserPackages = true;
    sharedModules = [inputs.nix-index-database.hmModules.nix-index];
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
