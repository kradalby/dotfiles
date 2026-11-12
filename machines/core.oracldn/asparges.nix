{ config, ... }:
let
  cfg = config.services.asparges;
in
{
  # tag:asparges key from infrastructure/tailscale (authkey_asparges.tf).
  # Root-only; the module reads it via LoadCredential.
  age.secrets.asparges-tskey.file = ../../secrets/asparges-tskey.age;

  # Beta, laid out as production will be: going live changes hostname,
  # baseURL and noindex, not the data dir.
  services.asparges = {
    enable = true;
    hostname = "asparges-beta";
    baseURL = "https://beta.aspargesgaarden.no";
    listenAddr = "127.0.0.1:63464";
    noindex = true;
    tailscaleKeyPath = config.age.secrets.asparges-tskey.path;
    # The farm's booking calendar, public; read every 5 minutes.
    calendarURL = "https://calendar.google.com/calendar/ical/klatrerosen.no_hgf7kiksq8hrmilogq5nd6f4rs%40group.calendar.google.com/public/basic.ics";
  };

  services.vhost."beta.aspargesgaarden.no".proxyPass = "http://${cfg.listenAddr}";

  # The snapshot opens the db as root; run first, it leaves root-owned
  # -wal/-shm the service and litestream cannot write.
  systemd.services."sqlite-backup-asparges.db".after = [ "asparges.service" ];
}
