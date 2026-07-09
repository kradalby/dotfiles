{
  pkgs,
  lib,
  config,
  ...
}: {
  services.postfix = {
    enable = true;
    settings.main.myhostname = "${config.networking.hostName}.${config.networking.domain}";
    enableHeaderChecks = false;
    setSendmail = true;
    enableSubmission = false;
    settings.main.relayhost = ["smtp.fap.no:25"];
  };

  # Deferred-queue growth is the only signal of silent mail loss on the
  # relay path (alerts, cron mail). Scraped fleet-wide on :9154.
  services.prometheus.exporters.postfix = {
    enable = true;
    systemd.enable = true;
  };
}
