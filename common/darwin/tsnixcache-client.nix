# Auto-push locally-built paths to the gigabuilder cache (nix post-build hook).
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
    package = inputs.tsnixcache.packages.${pkgs.stdenv.hostPlatform.system}.default;
    publicKey = cache.publicKey;
    substituters = [];
    postBuildHook.enable = true;
  };
}
