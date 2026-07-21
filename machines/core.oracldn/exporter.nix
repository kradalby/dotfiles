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
  # TODO: create the secret, then wire it here to enable the GitHub token and
  # unattended tailnet join:
  #   ragenix -e secrets/ghdl.age   # GHDL_GITHUB_TOKEN=...\nTS_AUTHKEY=...
  # then add:
  #   age.secrets.ghdl.file = ../../secrets/ghdl.age;
  #   services.ghdl.environmentFile = config.age.secrets.ghdl.path;
  # Until then ghdl runs unauthenticated (low GitHub rate limit, no auto-join).
  services.ghdl.enable = true;
}
