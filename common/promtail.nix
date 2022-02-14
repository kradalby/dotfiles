{ config, ... }:
let
  site = builtins.replaceStrings [ ".fap.no" ] [ "" ] config.networking.domain;
in
{
  services.promtail = {
    enable = true;

    extraFlags = [
      "--client.external-labels=host=${config.networking.hostName}.${site}"
    ];

    configuration = {
      server.disable = true;

      clients = [{
        url = "https://loki.oracldn.fap.no/loki/api/v1/push";
        # url = "http://10.69.0.206:3100/loki/api/v1/push";
      }];

      scrape_configs = [{
        job_name = "journal";
        journal = {
          json = true;
          max_age = "12h";
          labels.job = "systemd-journal";
        };
        relabel_configs = [
          # {
          #   source_labels = [ "__journal__hostname" ];
          #   target_label = "host";
          # }
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
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    onFailure = [ "notify-discord@%n.service" ];
  };
}
