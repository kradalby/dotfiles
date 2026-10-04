{ pkgs, ... }:
let
  policy = (pkgs.formats.json { }).generate "garnix-log-retention.json" {
    policy = {
      description = "Keep CI and nginx logs for 30 days";
      default_state = "hot";
      states = [
        {
          name = "hot";
          actions = [ ];
          transitions = [
            {
              state_name = "delete";
              conditions.min_index_age = "30d";
            }
          ];
        }
        {
          name = "delete";
          actions = [
            {
              delete = { };
              retry = {
                count = 3;
                backoff = "exponential";
                delay = "1m";
              };
            }
          ];
          transitions = [ ];
        }
      ];
      ism_template = [
        {
          index_patterns = [
            "garnix-build-logs-*"
            "garnix-system-*"
            "nginx-*"
          ];
          priority = 100;
        }
      ];
    };
  };
in
{
  systemd.services.opensearch-log-retention = {
    description = "Configure OpenSearch log retention";
    wantedBy = [ "multi-user.target" ];
    requires = [ "opensearch.service" ];
    after = [ "opensearch.service" ];
    restartTriggers = [ policy ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.python3}/bin/python3 ${./log-retention.py} http://127.0.0.1:9200 ${policy}";
      TimeoutStartSec = "5min";
      DynamicUser = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
    };
  };
  systemd.timers.opensearch-log-retention = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };
}
