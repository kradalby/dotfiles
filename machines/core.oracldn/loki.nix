{ pkgs, lib, config, ... }:
let
  retention = "168h";

  domain = "loki.oracldn.fap.no";
in
{
  services.loki = {
    enable = true;


    configuration = {
      server = {
        http_listen_port = 3100;
        grpc_listen_port = 9095;
      };

      auth_enabled = false;

      schema_config = {
        configs = [
          {
            from = "2020-05-15";
            store = "boltdb";
            object_store = "filesystem";
            schema = "v11";
            index = {
              prefix = "index_";
              period = retention;

            };
          }
        ];
      };

      # Distributor
      distributor.ring.kvstore.store = "inmemory";

      # Ingester
      ingester = {
        lifecycler.ring = {
          kvstore.store = "inmemory";
          replication_factor = 1;
        };
        lifecycler.interface_names = [ config.my.lan "wg0" "tailscale0" "enp1s0" ];
        chunk_encoding = "snappy";
        # Disable block transfers on shutdown
        max_transfer_retries = 0;
      };

      storage_config = {
        boltdb = {
          directory = "${config.services.loki.dataDir}/index";
        };

        filesystem = {
          directory = "${config.services.loki.dataDir}/storage";
        };
      };

      chunk_store_config = {
        max_look_back_period = retention;
      };

      table_manager = {
        retention_deletes_enabled = true;
        retention_period = retention;
      };

      limits_config.ingestion_burst_size_mb = 16;

      ruler = {
        # storage = {
        #   type = "local";
        #   local.directory = rulerDir;
        # };
        rule_path = "${config.services.loki.dataDir}/ruler";
        # alertmanager_url = "http://alertmanager.r";
        ring.kvstore.store = "inmemory";
      };

      # Query splitting and caching
      query_range = {
        split_queries_by_interval = "24h";
        cache_results = true;
      };
    };
  };

  security.acme.certs."${domain}".domain = domain;

  services.nginx.virtualHosts."${domain}" = {
    forceSSL = true;
    useACMEHost = domain;
    locations."/" = {
      proxyWebsockets = true;
      proxyPass = "http://127.0.0.1:${toString config.services.loki.configuration.server.http_listen_port}";
      extraConfig = ''
        proxy_read_timeout 1800s;
        proxy_redirect off;
        proxy_connect_timeout 1600s;
        access_log off;
      '';
    };
    locations."/ready" = {
      proxyWebsockets = true;
      proxyPass = "http://127.0.0.1:${toString config.services.loki.configuration.server.http_listen_port}";
      extraConfig = ''
        auth_basic off;
        access_log off;
      '';
    };
  };
}
