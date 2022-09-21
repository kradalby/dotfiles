{lib, ...}:
with lib; let
  prometheusExporter = name: port: {
    name = "${name}-exporter";
    tags = ["${name}-exporter" "prometheus"];
    port = port;
    check = {
      name = "${name} health check";
      http = "http://127.0.0.1:${toString port}/metrics";
      interval = "60s";
      timeout = "1s";
    };
  };
in {inherit prometheusExporter;}
