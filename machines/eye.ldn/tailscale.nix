{
  config,
  pkgs,
  lib,
  flakes,
  ...
}:
(import ../../common/funcs/tailscale.nix {inherit config pkgs lib flakes;}).tailscale
{
  reauth = false;
  exitNode = true;
  tags = ["tag:ldn" "tag:server"];
}
