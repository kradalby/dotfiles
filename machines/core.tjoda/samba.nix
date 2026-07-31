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

  # The missing half: smbd listened on nothing reachable, so every share here
  # was dark. Tailnet-only per services.md tier 3 -- group:kradalby already holds
  # the wildcard grant to tag:storage in infrastructure/tailscale, and core.tjoda
  # carries that tag. SMB2+ only, so no 137-139.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 445 ];

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

      # REMIND: one-time `mkdir -p /pictures/album/gallery` +
      # `chown storage:storage /pictures/album/gallery /pictures/hugin`.
      # Deliberately not systemd.tmpfiles: both disks are `nofail`, and a missed
      # mount must fail closed (writes denied) rather than quietly filling the
      # boot SSD with a 2TB album.
      #
      # gallery/ rather than the drive root because osxphotos --cleanup deletes
      # anything in the export dir it did not put there -- including ext4's
      # root-owned lost+found.
      album = pictureShare "/pictures/album/gallery";
      hugin = pictureShare "/pictures/hugin";
    };
  };
}
