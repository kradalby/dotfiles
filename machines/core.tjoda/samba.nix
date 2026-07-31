{ ... }:
let
  # Files land as storage:storage so whatever serves hugin can read them.
  pictureShare = path: {
    inherit path;
    browsable = "yes";
    public = "no";
    writeable = "yes";
    "valid users" = "kradalby";
    "force user" = "storage";
    "force group" = "storage";
    "create mask" = "0755";
    "directory mask" = "0775";
  };
in
{
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

      # Ownership is set by hand: a tmpfiles rule would recreate these on the
      # boot SSD when a `nofail` mount is missing.
      album = pictureShare "/pictures/album";
      hugin = pictureShare "/pictures/hugin";
    };
  };
}
