{ config, ... }:
{
  services.promtail = {
    enable = true;
    configuration = {
      server.disable = true;

      clients = [{
        url = "https://loki.terra.fap.no/loki/api/v1/push";
      }];

      scrape_configs = [{
        job_name = "journal";
        journal = {
          json = true;
          max_age = "12h";
          labels.job = "systemd-journal";
        };
        relabel_configs = [
          {
            source_labels = [ "__journal__hostname" ];
            target_label = "host";
          }
          {
            source_labels = [ "__journal__systemd_unit" ];
            target_label = "systemd_unit";
          }
          {
            source_labels = [ "__journal_syslog_identifier" ];
            target_label = "syslog_identifier";
          }
        ];
      }];
    };
  };

  systemd.services.promtail = {
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" "dns-ready.service" ];
    after = [ "dns-ready.service" ];
    onFailure = [ "notify-discord@%n.service" ];
  };
}
