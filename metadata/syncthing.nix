{
  devices =
    let
      device = id: {
        inherit id;
        introducer = false;
        autoAcceptFolders = false;
      };
    in
    {
      "kratail2" = device "JE6KCCC-C4UPRRJ-QKXGGWJ-7VSUSP4-SB4ZMDS-EONA44U-NDMVKAB-74QTDQG";
      "krair" = device "NVYXJFI-XRYR3S3-WLLNMMH-QIOPEHB-5WAB44G-4Y2KE3G-HCFNVNI-Z5QBAQ5";
      "core.tjoda" = device "5WDUBHD-ZWYSK7Z-IQV37HN-ELB2X4X-WOAADCJ-ODUV2FH-BX62TRL-HHAH3AJ";
      "dev.oracfurt" = device "JKYGSCI-JXCDYUM-BPOU6RM-TORXNQE-VFNAKQV-PTTBORO-FEEJIZE-FVQDIAL";
      "dev.ldn" = device "5S3RMNQ-QS6SAJ7-AWGAIW7-BEILMOS-UYHYBCW-EDYSQZA-425UFC2-PVF2BAN";
      "storage.ldn" = device "5IPOAQL-TKKUN7K-DGL26VV-JZGMADN-CCS2M4E-J5UCEJ7-BPQIP7B-W5VNRAN";
      "storage.bassan" = device "7CRTZEY-WHLMLLV-YI4YH5V-KI5FDAS-7NA46SW-DNDD2I4-5DGPFL6-2NFA2QP";

      "dev.oracfurt-cooklang" = device "JJTIDK5-36EOH5Y-LJYBN65-S4QDT7X-6IQMP6U-FSDNREU-2EVPA6H-TAFJ6AQ";
    };

  storage = [
    "krair"
    "core.tjoda"
    "storage.ldn"
    # storage.bassan is intentionally NOT here: it is an untrusted offsite
    # mirror, shared to encrypted (receiveencrypted) from common/syncthing-storage.nix,
    # not a plaintext peer.
  ];

  # The storage folder set. Single source for both the senders
  # (common/syncthing-storage.nix) and the encrypted mirror's per-folder
  # receiveencrypted overrides (machines/storage.bassan/syncthing.nix), so a
  # new folder can never reach the mirror unencrypted.
  storageFolders = {
    "/storage/software" = {
      id = "vpgyn-cj2mg";
      path = "/storage/software";
    };
    "/storage/pictures" = {
      id = "orqnv-bg72d";
      path = "/storage/pictures";
    };
    "/storage/backup" = {
      id = "9bjac-k65uu";
      path = "/storage/backup";
    };
    "/storage/books" = {
      id = "ww4gn-xgy9i";
      path = "/storage/books";
    };
    "kradalby - Sync" = {
      id = "xTDuT-kZeuK";
      path = "/storage/sync/kradalby";
    };
  };
}
