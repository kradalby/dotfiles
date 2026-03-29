{
  config,
  pkgs,
  ...
}: let
  musicDir = "/var/lib/owntone/music";
  radioDir = "${musicDir}/radio";

  nrkP3Playlist = pkgs.writeText "nrk-p3.m3u" ''
    #EXTM3U
    #EXTINF:-1,NRK P3 - Musikk
    https://lyd.nrk.no/icecast/mp3/high/s0w7hwn47m/p3
  '';
in {
  imports = [
    ../../modules/owntone.nix
  ];

  services.owntone = {
    enable = true;
    openFirewall = true;

    settings = {
      general = {
        bind_address = "0.0.0.0";
      };
      library = {
        name = "P3 Streamer";
        directories = [musicDir];
      };
    };

    controller = {
      enable = true;
      openFirewall = true;
      settings = {
        playlist_name = "NRK P3";
        weekday = [
          {name = "KITCHEN"; volume = 10;}
          {name = "LAMP"; volume = 10;}
          {name = "OFFICE"; volume = 10;}
        ];
        weekend = [
          {name = "KITCHEN"; volume = 10;}
          {name = "SHELF"; volume = 10;}
          {name = "RIGHT"; volume = 10;}
          {name = "LIVING ROOM"; volume = 10;}
        ];
      };
    };
  };

  # Deploy NRK radio playlists into OwnTone's music directory.
  # L+ creates a symlink, replacing any existing one.
  systemd.tmpfiles.rules = [
    "d ${radioDir} 0755 ${config.services.owntone.user} ${config.services.owntone.group} -"
    "L+ ${radioDir}/nrk-p3.m3u - - - - ${nrkP3Playlist}"
  ];

  # Expose OwnTone web UI and JSON API via Tailscale.
  services.tailscale.services.owntone = {
    endpoints = {
      "tcp:80" = "http://127.0.0.1:${toString config.services.owntone.settings.library.port}";
      "tcp:443" = "http://127.0.0.1:${toString config.services.owntone.settings.library.port}";
    };
  };

  # Expose p3-controller via Tailscale for Apple Shortcut integration.
  services.tailscale.services.p3 = {
    endpoints = {
      "tcp:80" = "http://127.0.0.1:${toString config.services.owntone.controller.port}";
      "tcp:443" = "http://127.0.0.1:${toString config.services.owntone.controller.port}";
    };
  };
}
