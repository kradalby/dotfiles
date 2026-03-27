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
  };

  # Deploy NRK radio playlists into OwnTone's music directory.
  # L+ creates a symlink, replacing any existing one.
  systemd.tmpfiles.rules = [
    "d ${radioDir} 0755 ${config.services.owntone.user} ${config.services.owntone.group} -"
    "L+ ${radioDir}/nrk-p3.m3u - - - - ${nrkP3Playlist}"
  ];

  # Expose OwnTone web UI and JSON API via Tailscale for
  # remote access and Apple Shortcut integration.
  services.tailscale.services.owntone-ldn = {
    endpoints = {
      "tcp:80" = "http://127.0.0.1:${toString config.services.owntone.settings.library.port}";
      "tcp:443" = "http://127.0.0.1:${toString config.services.owntone.settings.library.port}";
    };
  };
}
