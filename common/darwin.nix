{...}: {
  imports = [
    ./ca.nix
    ./darwin/system.nix
    ./darwin/fonts.nix
    ./darwin/nix.nix

    ./environment.nix
  ];
}
