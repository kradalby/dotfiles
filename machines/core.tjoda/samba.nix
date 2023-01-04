{lib, ...}: let
  guestShare = path: {
    inherit path;
    browsable = "yes";
    "guest ok" = "yes";
    "read only" = "yes";
  };
in {
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

      map to guest = bad user
    '';
    shares = {
      storage = {
        path = "/storage";
        browsable = "yes";
        "guest ok" = "no";
        writeable = "yes";
        "valid users" = "kradalby";
        "force user" = "storage";
        "force group" = "storage";
        "create mask" = "0755";
        "directory mask" = "0775";
      };

      TimeMachineTjoda = {
        path = "/storage/timemachine/%U";
        "valid users" = "%U";
        browsable = "yes";
        writeable = "yes";
        "fruit:time machine" = "yes";
        "fruit:time machine max size" = "600G";
      };

      software = guestShare "/storage/software";
      libraries = guestShare "/storage/libraries";
      pictures = guestShare "/storage/pictures";

      dropbox = {
        path = "/storage/dropbox";
        browsable = "yes";
        writeable = "yes";
        "guest ok" = "yes";
      };
    };
  };
}
