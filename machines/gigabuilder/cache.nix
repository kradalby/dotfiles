{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: {
  # gigabuilder's /nix/store IS the cache content tsnixcache serves, incl.
  # offloaded CI build outputs that are NOT gcroots here. The fleet's automatic
  # nix-collect-garbage (common/nix.nix) would delete every such unreferenced
  # path on each run — wiping the cache. tsnixcache's own disk-pressure gc.rules
  # (below) is the collector instead, so disable the time-based fleet GC here.
  nix.gc.automatic = lib.mkForce false;
  # Keep auto-optimise (dedup hardlinking) — it only saves space, never deletes.

  # Lightweight, generations-only cleanup: without the fleet GC, old system
  # profile generations stay pinned as gcroots forever (tsnixcache won't evict
  # roots). This unroots generations older than 30d via nix-env — it does NOT run
  # nix-collect-garbage, so the cache is untouched; tsnixcache's disk-pressure GC
  # reclaims the now-unreferenced paths when it needs the space.
  systemd.services.prune-system-generations = {
    description = "Unroot NixOS system generations older than 30d (no store collection)";
    serviceConfig.Type = "oneshot";
    script = "${config.nix.package}/bin/nix-env -p /nix/var/nix/profiles/system --delete-generations 30d";
  };
  systemd.timers.prune-system-generations = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
    };
  };
  # The tsnixcache service runs as user `tsnixcache`; the signing key must be
  # readable by it (agenix defaults to root:root 0400).
  age.secrets.tsnixcache-sign-key = {
    file = ../../secrets/tsnixcache-sign-key.age; # from: tsnixcache key generate
    owner = "tsnixcache";
    group = "tsnixcache";
  };
  # The tsnet nodes reuse the host's join keys (both reusable): tailscale-preauthkey
  # (base/tskey.nix) for the SaaS tailnet, and headscale-sfiber-client-preauthkey
  # (default.nix) for the sfiber headscale. tsnixcache reads them too, so grant it
  # access — the system tailscaled instances run as root and still read them.
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
    package = inputs.tsnixcache.packages.${pkgs.system}.default;
    signKeyFile = config.age.secrets.tsnixcache-sign-key.path;

    listen = ["10.68.0.1:5000"]; # local/subnet only, never wan0
    serveCompression = "zstd";

    # Serve on two control planes: the kradalby tailnet and the sandefjordfiber
    # headscale. Same hostname, distinct nodes (separate dir state).
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

    # Disk-pressure GC so /nix/store on NVMe0 never fills. Last rule is the
    # emergency valve: near-full, drop anything older than a day.
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

  # tsnixcache binds 10.68.0.1 (incusbr0), but incus assigns that address after
  # its daemon starts. Unordered, tsnixcache races the bridge, the bind silently
  # fails, and the unit sits active-but-serving-nothing until restarted (every
  # boot). Gate it on a oneshot that waits for the address — and fail loud if it
  # never shows, rather than come up dead.
  systemd.services.tsnixcache-wait-incusbr0 = {
    description = "Wait for incusbr0 to own 10.68.0.1 (tsnixcache listen address)";
    after = ["incus.service" "sys-subsystem-net-devices-incusbr0.device"];
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
    after = ["tsnixcache-wait-incusbr0.service"];
    requires = ["tsnixcache-wait-incusbr0.service"];
  };
}
