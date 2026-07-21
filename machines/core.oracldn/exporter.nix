{ config, ... }: {
  age.secrets.oci-usage-exporter = {
    file = ../../secrets/oci-usage-exporter.age;
  };

  services.oci-usage-exporter = {
    enable = true;
    listenAddr = "localhost:63461";
    environmentFile = config.age.secrets.oci-usage-exporter.path;
  };

  services.tasmota-exporter = {
    enable = true;
    listenAddr = "localhost:63459";
  };

  services.homewizard-p1-exporter = {
    enable = true;
    listenAddr = "localhost:63460";
  };

  # ghdl download-metrics scraper — joins the tailnet as its own node "ghdl",
  # serving /api and /metrics on :80/:443. Scraped in monitoring.nix; db backed
  # up in litestream.nix; dashboards + Infinity datasource in grafana.nix.
  #
  # The secret (secrets/ghdl.age) carries GHDL_GITHUB_TOKEN. TS_AUTHKEY (for the
  # unattended tailnet join) still needs adding once the tailscale_tailnet_key
  # is applied in ~/git/infrastructure: `tofu -chdir=tailscale apply` then
  # `ragenix -e secrets/ghdl.age` to append TS_AUTHKEY=<tofu output ghdl_authkey>.
  age.secrets.ghdl.file = ../../secrets/ghdl.age;

  services.ghdl = {
    enable = true;
    # 9091 is the pushgateway; ghdl serves its real endpoints over tsnet on :80
    # anyway, so the local listener just needs a free loopback port.
    localAddr = "127.0.0.1:63462";
    environmentFile = config.age.secrets.ghdl.path;
  };
}
