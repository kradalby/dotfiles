{...}: let
in {
  services.tasmota-exporter = {
    enable = true;
    listenAddr = "localhost:63459";
  };
}
