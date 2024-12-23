{
  pkgs,
  lib,
  config,
  ...
}: {
  nginx = import ./nginx.nix {inherit pkgs lib config;};
}
