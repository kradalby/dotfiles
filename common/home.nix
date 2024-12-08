{
  config,
  pkgs,
  lib,
  flakes,
  ...
}: {
  environment.homeBinInPath = true;
  home-manager = {
    verbose = true;
    backupFileExtension = "hm_bak~";
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {inherit flakes;};
    users = {
      kradalby = {
        imports = [
          ../home
        ];
        programs.git = {
          extraConfig = {
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
