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
}
