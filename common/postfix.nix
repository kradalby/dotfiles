{
  pkgs,
  lib,
  config,
  ...
}: {
  services.postfix = {
    enable = true;
    # Consistent, real fap.no sender identity on every host: mail leaves as
    # <local>@<host>.<site>.fap.no, so the relay (gigabuilder) and gigahost
    # see a coherent fap.no origin.
    settings.main.myhostname = "${config.networking.hostName}.${config.networking.domain}";
    settings.main.myorigin = "${config.networking.hostName}.${config.networking.domain}";
    enableHeaderChecks = false;
    setSendmail = true;
    enableSubmission = false;
    # smtp.fap.no is the fleet relay (-> gigabuilder over the tailnet), which
    # relays outbound through gigahost. gigabuilder overrides this to gigahost.
    settings.main.relayhost = ["smtp.fap.no:25"];
    # All system mail — cron, alerts, restic/rustic failures, root — lands in
    # the personal inbox.
    rootAlias = "kristoffer@dalby.cc";
  };

  # Deferred-queue growth is the only signal of silent mail loss on the
  # relay path (alerts, cron mail). Scraped fleet-wide on :9154.
  services.prometheus.exporters.postfix = {
    enable = true;
    systemd.enable = true;
  };
}
