# Disk layout; the README explains what goes where and why.
let
  # TODO(install): real ids from `ls -l /dev/disk/by-id`.
  id = name: "/dev/disk/by-id/TODO-${name}";

  # Whole-disk pool member behind one GPT partition.
  member = pool: device: {
    type = "disk";
    inherit device;
    content = {
      type = "gpt";
      partitions.zfs = {
        size = "100%";
        content = {
          type = "zfs";
          inherit pool;
        };
      };
    };
  };

  # shortcut: only ssd0's ESP is mounted, so losing ssd0 needs a manual boot
  # from ssd1. Mirror the ESP if that recovery ever has to be hands-off.
  system = device: esp: {
    type = "disk";
    inherit device;
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
          }
          // esp;
        };
        zfs = {
          size = "100%";
          content = {
            type = "zfs";
            pool = "rpool";
          };
        };
      };
    };
  };

  pool = mode: datasets: {
    type = "zpool";
    inherit mode datasets;
    options.ashift = "12";
    rootFsOptions = {
      compression = "zstd";
      atime = "off";
      xattr = "sa";
      acltype = "posixacl";
      mountpoint = "none";
    };
  };

  mounted = mountpoint: {
    type = "zfs_fs";
    inherit mountpoint;
    options.mountpoint = "legacy";
  };

  # Handed to Incus as a storage pool source; never mounted by the host.
  unmounted = {
    type = "zfs_fs";
    options.mountpoint = "none";
  };

  under =
    base: names:
    builtins.listToAttrs (
      map (n: {
        name = n;
        value = mounted "${base}/${n}";
      }) names
    );
in
{
  # Pools without a mounted dataset are not imported by fileSystems alone.
  boot.zfs.extraPools = [
    "fast"
    "solo"
    "storage"
  ];

  disko.devices = {
    disk = {
      ssd0 = system (id "ssd0") {
        mountpoint = "/boot";
        mountOptions = [ "umask=0077" ];
      };
      ssd1 = system (id "ssd1") { };

      nvme0 = member "fast" (id "nvme0");
      nvme1 = member "fast" (id "nvme1");
      nvme2 = member "solo" (id "nvme2");
    }
    // builtins.listToAttrs (
      map (n: {
        name = "hdd${toString n}";
        value = member "storage" (id "hdd${toString n}");
      }) (builtins.genList (n: n) 6)
    );

    zpool = {
      rpool = pool "mirror" {
        root = mounted "/";
        nix = mounted "/nix";
        incus = unmounted;
      };

      # "" is a plain stripe.
      fast = pool "" (
        {
          incus = unmounted;
        }
        // under "/fast" [ "hugin" ]
      );

      solo = pool "" { incus = unmounted; };

      storage = pool "raidz2" (
        under "/storage" [
          "software"
          "pictures"
          "backup"
          "books"
          "sync"
          "album"
          "garage"
          "files"
        ]
        // {
          # syncoid target for `solo`.
          replica = unmounted;
        }
      );
    };
  };
}
