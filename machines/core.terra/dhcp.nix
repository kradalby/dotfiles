{ config, ... }: {
  services.dhcpd4 = {
    enable = true;
    interfaces = [ config.my.lan ];
    extraConfig = ''
      option subnet-mask 255.255.255.0;

      subnet 10.60.0.0 netmask 255.255.255.0 {
        option broadcast-address 10.60.0.255;
        option domain-name-servers 10.60.0.1;
        option routers 10.60.0.1;
        interface ${config.my.lan};
        range 10.60.0.171 10.60.0.250;
      }
    '';
    machines = [
    ];
  };
}
