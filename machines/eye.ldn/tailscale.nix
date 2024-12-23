{
  config,
  pkgs,
  lib,
  ...
}:
(import ../../common/funcs/tailscale.nix {inherit config pkgs lib;}).tailscale
{
  reauth = false;
  exitNode = true;
  tags = ["tag:ldn" "tag:server"];
}
