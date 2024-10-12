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
      {name = "wan1";}
    ];
    lan = {
      trusted = [
        {
          name = "lanbr0";
          ipv4 = "10.65.0.1";
        }
        {name = "tailscale0";}
        {name = "wg0";}
        {name = "podman*";}
      ];
      untrusted = [
        {
          name = "iot0";
          ipv4 = "192.168.156.1";
          prefix = "192.168.156.0/24";
        }
      ];
    };
  };
}
