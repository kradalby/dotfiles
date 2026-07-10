{
  config,
  lib,
  pkgs,
  ...
}: let
  cache = import ../metadata/tsnixcache.nix;
in {
  i18n.defaultLocale = "en_US.UTF-8";

  # Cap boot entries so /boot can't fill. GC's --delete-older-than is by age;
  # a dev box that rebuilds many times within the window still piles up kernels
  # (dev.ldn hit 32 generations on a 249 MB /boot). configurationLimit bounds it
  # by count regardless of age. 5 is plenty — rollbacks never go deeper.
  # mkDefault so a host can override. Both loaders set — the option is inert on
  # whichever isn't enabled.
  boot.loader.systemd-boot.configurationLimit = lib.mkDefault 5;
  boot.loader.grub.configurationLimit = lib.mkDefault 5;

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
      # Weekly. `dates` is an OnCalendar spec; "2weeks" isn't valid, so an
      # earlier "2weeks" silently disabled the timer. Twice-a-month wasn't
      # enough on dev boxes that rebuild often — weekly keeps the store lean.
      dates = "weekly";
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
      # minio is abandoned upstream and flagged insecure in 26.05 (multiple
      # unpatched CVEs, no fixed version in nixpkgs). Only core.tjoda builds
      # it. Revisit the version string on each bump and migrate off minio
      # (Garage/SeaweedFS) — see the deploy notes.
      "minio-2025-10-15T17-29-55Z"
    ];
  };

  # TODO: why doesnt this always work?
  # system.copySystemConfiguration = true;
}
