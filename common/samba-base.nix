{
  lib,
  config,
  ...
}: let
  site = builtins.replaceStrings [".fap.no"] [""] config.networking.domain;
in {
  services.samba = {
    # REMIND: `smbpasswd -a`

    enable = true;
    settings = {
      global = {
        "netbios name" = "${config.networking.hostName}-${site}";
        "mdns name" = "mdns";
        "server string" = "Samba on ${config.networking.hostName}.${site}";

        # This would preferrably be SMB3, but iOS Files.app does not
        # support authing/handshaking over SMB3.
        "min protocol" = "SMB2";
        "encrypt passwords" = true;

        "wins support" = true;
        "local master" = true;
        "preferred master" = true;
        workgroup = "WORKGROUP";

        "vfs objects" = "catia fruit streams_xattr";

        # macOS optimalisation
        "fruit:aapl" = true;
        "fruit:metadata" = "stream";
        "fruit:model" = "MacPro7,1";
        "fruit:posix_rename" = true;
        "fruit:veto_appledouble" = false;
        "fruit:wipe_intentionally_left_blank_rfork" = true;
        "fruit:delete_empty_adfiles" = true;
        "fruit:advertise_fullsync" = true;
      };
    };
  };
}
