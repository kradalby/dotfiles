update all nix and flake dependencies

- run `nix flake update`
- run `nix flake check`
- ensure `nix build` and all modules passes clean
- ensure all modules and builds have all deprecated features fixed
- for every versioned build function, like `pkgs.buildGo125Module`
  - make sure they are upgraded to the latest version
  - make sure we cover this for all languages
- look for other versions defined in Nix to upgrade
