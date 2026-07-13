# Auto-push locally-built paths to the gigabuilder cache (nix post-build hook).
{
  config,
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

  # The client module only references the binary by store path (post-build
  # hook / watch daemon), so expose it on $PATH too for ad-hoc client use
  # (tsnixcache push/gc/waitfor/watch).
  environment.systemPackages = [config.services.tsnixcache-client.package];
}
