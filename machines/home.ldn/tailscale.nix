{
  config,
  pkgs,
  lib,
  ...
}:
(import ../../common/funcs/tailscale.nix {inherit config pkgs lib;}).tailscale
{
  preAuthKey = "tskey-kvnj2K3CNTRL-avaPtyihVzQtMSWPG4nFg"; # onetime key
  reauth = false;
  exitNode = true;
  tags = ["tag:ldn" "tag:server"];
}
