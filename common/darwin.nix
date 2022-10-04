{...}: {
  require = [
    ./darwin/environment.nix
    ./darwin/system.nix
    ./darwin/fonts.nix
    ./darwin/nix.nix

    ./environment.nix
  ];
}
