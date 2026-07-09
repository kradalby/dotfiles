{pkgs, ...}: {
  # /pictures/album (sdd): daily mirror of the primary library. /storage stays
  # primary; this is a copy on a dedicated drive.
  systemd.services.mirror-pictures-album = {
    description = "Mirror /storage/pictures -> /pictures/album";
    # RequiresMountsFor guards the --delete: if either side is unmounted the
    # service refuses to start, so an empty source can never wipe the mirror.
    unitConfig.RequiresMountsFor = ["/storage/pictures" "/pictures/album"];
    # Belt-and-suspenders: abort if the source is somehow empty.
    serviceConfig = {
      Type = "oneshot";
      ExecStartPre = "${pkgs.bash}/bin/bash -c 'test -n \"$(ls -A /storage/pictures)\"'";
      ExecStart = "${pkgs.rsync}/bin/rsync -a --delete --exclude='.stfolder' /storage/pictures/ /pictures/album/";
    };
  };
  systemd.timers.mirror-pictures-album = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "30m";
    };
  };

  # /pictures/hugin (sda): receive the generated album straight from the Mac.
  # Mirrors the retired core.terra receiver (devices via the storage cluster).
  services.syncthings.storage.settings.folders."/fast/hugin" = {
    id = "dd5mf-nwmas";
    path = "/pictures/hugin";
    devices = ["krair" "dev.ldn"];
    type = "receiveonly";
  };
}
