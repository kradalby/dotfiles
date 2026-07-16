# Auto-push new store paths to the gigabuilder cache (out-of-band watch daemon,
# so the push doesn't block build completion like the post-build hook does).
{
  inputs,
  pkgs,
  ...
}:
let
  cache = import ../metadata/tsnixcache.nix;
in
{
  imports = [ inputs.tsnixcache.nixosModules.tsnixcache-client ];

  services.tsnixcache-client = {
    enable = true;
    package = inputs.tsnixcache.packages.${pkgs.stdenv.hostPlatform.system}.default;
    publicKey = cache.publicKey;
    substituters = [ ];
    watch.enable = true;
  };
}
