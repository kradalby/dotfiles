{
  services.consul = {
    webUi = true;
    interface = {
      bind = "br0";
      advertise = "br0";
    };

    extraConfig = {
      server = true;
      bootstrap = true;
      datacenter = "ntnu";
      addresses = {
        http = "0.0.0.0";
      };
      connect = {
        enabled = true;
      };
    };
  };
}
