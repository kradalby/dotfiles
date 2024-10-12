{
  lib,
  config,
  ...
}: {
  networking.faptables = {
    enable = true;
    trace = false;
    wans = [
      {name = "wan0";}
    ];
    lan = {
      trusted = [
        {
          name = "lan0";
          ipv4 = "10.62.0.1";
        }
        {name = "tailscale0";}
        {name = "wg0";}
      ];
      untrusted = [
        {
          name = "selskap0";
          ipv4 = "192.168.200.1";
          prefix = "192.168.200.0/24";
        }
      ];
    };
  };
}
