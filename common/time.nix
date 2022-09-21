{
  services.chrony = {
    enable = false;
    servers = [
      "time1.google.com"
      "time2.google.com"
      "time3.google.com"
      "time4.google.com"

      # 0.uk.pool.ntp.org
      "143.210.16.201"
      "178.79.160.57"
      "217.114.59.3"
      "87.117.251.3"
    ];
    extraConfig = ''
      rtcsync
    '';
  };

  systemd.services.chrony.onFailure = ["notify-discord@%n.service"];

  services.timesyncd = {
    enable = true;
    servers = [
      "time1.google.com"
      "time2.google.com"
      "time3.google.com"
      "time4.google.com"

      # 0.uk.pool.ntp.org
      "143.210.16.201"
      "178.79.160.57"
      "217.114.59.3"
      "87.117.251.3"
    ];
    extraConfig = ''
      rtcsync
    '';
  };

  systemd.services.timesyncd.onFailure = ["notify-discord@%n.service"];
}
