{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
{
  # This /nix/store IS the cache tsnixcache serves, and CI outputs here aren't
  # gcroots — the fleet's time-based nix-collect-garbage would wipe them. Let
  # tsnixcache's disk-pressure GC (below) be the sole collector instead.
  nix.gc.automatic = lib.mkForce false;

  # Without the fleet GC, old system generations stay pinned as gcroots forever.
  # Unroot ones older than 30d (no store collection — tsnixcache reclaims later).
  systemd.services.prune-system-generations = {
    description = "Unroot NixOS system generations older than 30d";
    serviceConfig.Type = "oneshot";
    script = "${config.nix.package}/bin/nix-env -p /nix/var/nix/profiles/system --delete-generations 30d";
  };
  systemd.timers.prune-system-generations = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
    };
  };

  # tsnixcache runs as its own user; the signing key must be readable by it.
  age.secrets.tsnixcache-sign-key = {
    file = ../../secrets/tsnixcache-sign-key.age; # from: tsnixcache key generate
    owner = "tsnixcache";
    group = "tsnixcache";
  };
  # tsnixcache's tsnet nodes reuse the host's join keys, so grant it access.
  age.secrets.tailscale-preauthkey = {
    owner = "tsnixcache";
    group = "tsnixcache";
  };
  age.secrets.headscale-sfiber-client-preauthkey = {
    owner = "tsnixcache";
    group = "tsnixcache";
  };

  services.tsnixcache = {
    enable = true;
    package = inputs.tsnixcache.packages.${pkgs.stdenv.hostPlatform.system}.default;
    signKeyFile = config.age.secrets.tsnixcache-sign-key.path;

    listen = [ "10.68.0.1:5000" ]; # local/subnet only, never wan0
    serveCompression = "zstd";

    # Two control planes (kradalby tailnet + sfiber headscale), same hostname,
    # distinct node state.
    tsnet = [
      {
        hostname = "tsnixcache";
        authKeyFile = config.age.secrets.tailscale-preauthkey.path;
        dir = "/var/lib/tsnixcache/tsnet-kradalby";
      }
      {
        hostname = "tsnixcache";
        controlUrl = "https://headscale.sandefjordfiber.no";
        authKeyFile = config.age.secrets.headscale-sfiber-client-preauthkey.path;
        dir = "/var/lib/tsnixcache/tsnet-sfiber";
      }
    ];

    # Disk-pressure GC so the store never fills; last rule is the emergency valve.
    gc.rules = [
      {
        threshold = 80;
        olderThan = "20d";
      }
      {
        threshold = 90;
        olderThan = "10d";
      }
      {
        threshold = 95;
        olderThan = "5d";
      }
      {
        threshold = 99;
        olderThan = "1d";
      }
    ];
  };

  # incus assigns 10.68.0.1 only after its daemon starts, so tsnixcache races the
  # bridge and silently binds nothing. Gate it on the address appearing; fail loud
  # rather than come up dead.
  systemd.services.tsnixcache-wait-incusbr0 = {
    description = "Wait for incusbr0 to own 10.68.0.1 (tsnixcache listen address)";
    after = [
      "incus.service"
      "sys-subsystem-net-devices-incusbr0.device"
    ];
    serviceConfig.Type = "oneshot";
    script = ''
      for _ in $(seq 1 60); do
        ${pkgs.iproute2}/bin/ip -4 addr show incusbr0 2>/dev/null | grep -q "inet 10.68.0.1/" && exit 0
        sleep 1
      done
      echo "incusbr0 has no 10.68.0.1 after 60s — tsnixcache would bind nothing" >&2
      exit 1
    '';
  };
  systemd.services.tsnixcache = {
    after = [ "tsnixcache-wait-incusbr0.service" ];
    requires = [ "tsnixcache-wait-incusbr0.service" ];
  };
}
