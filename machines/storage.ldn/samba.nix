{ config, ... }: {
  imports = [
    ../../common/samba-base.nix
    ../../common/samba-storage.nix
  ];

  networking.firewall.interfaces.${config.my.lan} = {
    allowedTCPPorts = [
      139
      445
    ];
    allowedUDPPorts = [
      137
      138
    ];
  };

  services.samba = {
    settings = {
      TimeMachineLeiden = {
        path = "/storage/timemachine/%U";
        "valid users" = "%U";
        browsable = "yes";
        writeable = "yes";
        "fruit:time machine" = "yes";
        "fruit:time machine max size" = "1200G";
      };
    };
  };
}
