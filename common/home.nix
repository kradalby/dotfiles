{
  config,
  pkgs,
  lib,
  ...
}: {
  environment.homeBinInPath = true;
  home-manager = {
    verbose = true;
    backupFileExtension = "hm_bak~";
    useGlobalPkgs = true;
    useUserPackages = true;
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
