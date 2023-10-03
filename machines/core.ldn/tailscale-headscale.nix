{
  config,
  pkgs,
  lib,
  flakes,
  ...
}:
(import ../../common/funcs/tailscale-headscale.nix {inherit config pkgs lib flakes;}).tailscale
{
  reauth = false;
  # tags = ["tag:ldn" "tag:gateway" "tag:server"];
}
