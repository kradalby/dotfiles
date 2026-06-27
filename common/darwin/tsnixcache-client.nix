# Push locally-built paths to the gigabuilder cache via the tsnixcache watch
# daemon (launchd, low priority). The substituter itself is configured fleet-wide
# in common/darwin/nix.nix, so substituters = [] here to avoid a duplicate entry.
# A down cache only fails the push (logged + retried), never a build.
{
  inputs,
  pkgs,
  ...
}: let
  cache = import ../../metadata/tsnixcache.nix;
in {
  imports = [inputs.tsnixcache.darwinModules.tsnixcache-client];

  services.tsnixcache-client = {
    enable = true;
    package = inputs.tsnixcache.packages.${pkgs.system}.default;
    publicKey = cache.publicKey;
    substituters = [];
    watch.enable = true;
    postBuildHook.enable = false; # fatal on failure; we use the watch daemon
  };
}
