# Auto-push new store paths to the gigabuilder cache (out-of-band watch daemon,
# so the push doesn't block build completion like the post-build hook does).
# The watcher also covers offloaded (rosetta-builder) aarch64-linux builds — the
# result lands in the local store, which the daemon monitors.
{
  inputs,
  pkgs,
  ...
}:
let
  cache = import ../../metadata/tsnixcache.nix;
in
{
  imports = [ inputs.tsnixcache.darwinModules.tsnixcache-client ];

  services.tsnixcache-client = {
    enable = true;
    package = inputs.tsnixcache.packages.${pkgs.stdenv.hostPlatform.system}.default;
    publicKey = cache.publicKey;
    substituters = [ ];
    watch.enable = true;
  };
}
