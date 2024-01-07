{...}: {
  services.tasmota-exporter = {
    enable = true;
    listenAddr = "localhost:63459";
  };

  services.homewizard-p1-exporter = {
    enable = true;
    listenAddr = "localhost:63460";
  };
}
