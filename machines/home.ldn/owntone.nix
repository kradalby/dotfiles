{
  config,
  pkgs,
  ...
}:
let
  musicDir = "/var/lib/owntone/music";
  radioDir = "${musicDir}/radio";

  nrkP3Playlist = pkgs.writeText "nrk-p3.m3u" ''
    #EXTM3U
    #EXTINF:-1,NRK P3 - Musikk
    https://lyd.nrk.no/icecast/mp3/high/s0w7hwn47m/p3
  '';
in
{
  imports = [
    ../../modules/owntone.nix
  ];

  services.owntone = {
    enable = true;
    openFirewall = true;

    settings = {
      general = {
        bind_address = "0.0.0.0";
        # Audio drop-outs → upstream advises trying this toggle.
        high_resolution_clock = false;
      };
      library = {
        name = "P3 Streamer";
        directories = [ musicDir ];
      };
    };

    # Per-device AirPlay sections can't be expressed as attrsets.
    # reconnect = auto-rejoin speakers that spuriously drop mid-play.
    extraConfig = ''
      airplay "Right"       { reconnect = true }
      airplay "Living Room" { reconnect = true }
      airplay "Kitchen"     { reconnect = true }
      airplay "Lamp"        { reconnect = true }
      airplay "Office"      { reconnect = true }
      airplay "Shelf"       { reconnect = true }
    '';

    controller = {
      enable = true;
      openFirewall = true;

      hap = {
        enable = true;
        pin = "03145157";
      };

      settings = {
        playlist_name = "NRK P3";
        groups = [
          {
            name = "Living Room";
            members = [
              "Right"
              "Living Room"
            ];
          }
        ];
        weekday = [
          {
            name = "Kitchen";
            volume = 35;
          }
          {
            name = "Lamp";
            volume = 10;
          }
          {
            name = "Office";
            volume = 20;
          }
        ];
        weekend = [
          {
            name = "Kitchen";
            volume = 35;
          }
          {
            name = "Shelf";
            volume = 27;
          }
          {
            name = "Living Room";
            volume = 35;
          }
        ];
      };
    };
  };

  # Deploy the NRK radio playlist as a real file in OwnTone's music
  # directory. It must be a copy, not a symlink: following a symlink,
  # OwnTone names the playlist after the hash-prefixed store path, and
  # the link dangles once the store path is GC'd (which is exactly how
  # p3 broke — a stale pre-copy symlink outlived its target).
  #
  # tmpfiles `C`/`C+` only copies when the destination does not already
  # exist — it silently no-ops over any existing file or (dangling)
  # symlink, so it can neither migrate an old symlink nor propagate a
  # changed playlist. Force the copy on every activation instead.
  systemd.tmpfiles.rules = [
    "d ${radioDir} 0755 ${config.services.owntone.user} ${config.services.owntone.group} -"
  ];

  systemd.services.owntone-playlist = {
    description = "Install NRK P3 playlist into OwnTone music dir";
    wantedBy = [ "owntone.service" ];
    before = [ "owntone.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    # install overwrites unconditionally, so a stale symlink or an
    # outdated copy is always replaced with the current playlist.
    script = ''
      install -D -m0644 \
        -o ${config.services.owntone.user} -g ${config.services.owntone.group} \
        ${nrkP3Playlist} ${radioDir}/nrk-p3.m3u
    '';
  };

  # Expose OwnTone web UI and JSON API via Tailscale.
  services.tailscale.services.owntone = {
    endpoints = {
      "tcp:80" = "http://127.0.0.1:${toString config.services.owntone.settings.library.port}";
      # tcp:443 has no TLS termination — Tailscale VIP bug (tailscale/tailscale#19724, #18381); consumers use http. TODO(kradalby): revert when fixed.
      "tcp:443" = "http://127.0.0.1:${toString config.services.owntone.settings.library.port}";
    };
  };

  # Expose p3-controller via Tailscale for Apple Shortcut integration.
  services.tailscale.services.p3 = {
    endpoints = {
      "tcp:80" = "http://127.0.0.1:${toString config.services.owntone.controller.port}";
      # tcp:443 has no TLS termination — Tailscale VIP bug (tailscale/tailscale#19724, #18381); consumers use http. TODO(kradalby): revert when fixed.
      "tcp:443" = "http://127.0.0.1:${toString config.services.owntone.controller.port}";
    };
  };
}
