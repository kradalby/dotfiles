{ config, ... }: {
  services.dhcpd4 = {
    enable = true;
    interfaces = [ config.my.lan "selskap" ];
    extraConfig = ''
      option subnet-mask 255.255.255.0;

      subnet 10.62.0.0 netmask 255.255.255.0 {
        option broadcast-address 10.62.0.255;
        option domain-name-servers 10.62.0.1;
        option routers 10.62.0.1;
        interface ${config.my.lan};
        range 10.62.0.171 10.62.0.250;
      }

      subnet 192.168.200.0 netmask 255.255.255.0 {
        option broadcast-address 192.168.200.255;
        option domain-name-servers 192.168.200.1;
        option routers 192.168.200.1;
        interface selskap;
        range 192.168.200.100 192.168.200.200;
      }
    '';
    machines = [
    ];
  };

  systemd.services.dhcpd4.onFailure = [ "notify-discord@%n.service" ];
}
