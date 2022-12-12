{lib, ...}: {
  services.samba = {
    # REMIND: `smbpasswd -a`

    enable = true;

    extraConfig = ''
      netbios name = core-tjoda
      mdns name = mdns
      server string = Samba on core.tjoda

      min protocol = SMB2
      encrypt passwords = true

      # Windows discovery
      wins support = yes
      local master = yes
      preferred master = yes
      workgroup = WORKGROUP

      vfs objects = catia fruit streams_xattr

      # macOS optimalisation
      fruit:aapl = yes
      fruit:metadata = stream
      fruit:model = MacPro7,1
      fruit:posix_rename = yes
      fruit:veto_appledouble = no
      fruit:wipe_intentionally_left_blank_rfork = yes
      fruit:delete_empty_adfiles = yes
      fruit:advertise_fullsync = true
    '';
    shares = {
      storage = {
        path = "/storage";
        "read only" = "no";
        browsable = "yes";
        "valid users" = "storage, dalby, kradalby";
      };

      TimeMachineTjoda = {
        path = "/storage/timemachine/%U";
        "valid users" = "%U";
        browsable = "yes";
        writeable = "yes";
        "fruit:time machine" = "yes";
        "fruit:time machine max size" = "600G";
      };
    };
  };
}
