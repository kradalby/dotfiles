{
  config,
  lib,
  pkgs,
  ...
}: let
  cache = import ../metadata/tsnixcache.nix;
in {
  i18n.defaultLocale = "en_US.UTF-8";

  systemd.settings.Manager.DefaultLimitNOFILE = 1048576;
  security.pam.loginLimits = [
    {
      domain = "*";
      type = "hard";
      item = "nofile";
      value = "1048576";
    }
  ];

  nix = {
    settings = {
      connect-timeout = 5;
      fallback = true;
      accept-flake-config = true;
      # Let remote builders substitute missing deps from the configured
      # caches instead of failing when the local store lacks a closure.
      builders-use-substitutes = true;
      substituters =
        [
          "https://nix-community.cachix.org?priority=41"
          "https://numtide.cachix.org?priority=42"
        ]
        # The cache host serves from its own /nix/store, so don't make it
        # substitute from itself (a pointless tailscale round-trip).
        ++ lib.optionals
        (!(config.services ? tsnixcache && config.services.tsnixcache.enable))
        cache.substituters;
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
        cache.publicKey
      ];
    };

    package = pkgs.nixVersions.latest;
    extraOptions = "experimental-features = nix-command flakes";
    # settings = {
    #   auto-optimise-store = true;
    #   sandbox = true;
    #   trusted-users = [ "kradalby" ];
    # };

    gc = {
      automatic = true;
      dates = "2weeks";
      options = "--delete-older-than 10d";
    };

    optimise = {
      automatic = true;
      dates = ["03:45"];
    };

    # This is an attempt to make nix-index work:
    # https://github.com/nix-community/nix-index/issues/212
    # currently does not look like its working on Darwin
    # nixPath = ["nixpkgs=${pkgs.outPath}"];
    # channel.enable = true;
  };

  nixpkgs.config = {
    # allowUnfree is set in lib/box.nix via commonModules
    permittedInsecurePackages = [
      "litestream-0.3.13"
      "olm-3.2.16"
    ];
  };

  # TODO: why doesnt this always work?
  # system.copySystemConfiguration = true;
}
