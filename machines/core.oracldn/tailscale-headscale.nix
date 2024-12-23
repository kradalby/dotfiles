{
  config,
  pkgs,
  lib,
  ...
}:
(import ../../common/funcs/tailscale-headscale.nix {inherit config pkgs lib;}).tailscale
{
  reauth = false;
  # tags = ["tag:oracldn" "tag:gateway" "tag:server"];
}
