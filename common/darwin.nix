{...}: {
  imports = [
    ./ca.nix
    ./darwin/system.nix
    ./darwin/fonts.nix
    ./darwin/nix.nix
    ./darwin/tsnixcache-client.nix

    ./environment.nix
  ];
}
