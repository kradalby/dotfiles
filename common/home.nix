{
  config,
  pkgs,
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
      };
      root = {
        imports = [
          ../home
        ];
      };
    };
  };
}
