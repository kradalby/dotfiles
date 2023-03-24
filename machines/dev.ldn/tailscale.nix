{ config
, pkgs
, lib
, ...
}:
(import ../../common/funcs/tailscale.nix { inherit config pkgs lib; }).tailscale
{
  preAuthKey = "tskey-auth-kCme8a1CNTRL-aiNGyJHX8whnmkM6bpCFthRkXjJrNoji"; # onetime key
  reauth = false;
  exitNode = true;
  tags = [ "tag:ldn" "tag:server" ];
}
