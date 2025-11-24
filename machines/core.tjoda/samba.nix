{lib, ...}: {
  imports = [
    ../../common/samba-base.nix
    ../../common/samba-storage.nix
  ];

  services.samba = {
    settings = {
      TimeMachineTjoda = {
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
