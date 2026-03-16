{
  devices = let
    device = id: {
      inherit id;
      introducer = false;
      autoAcceptFolders = false;
    };
  in {
    "kramacbook" = device "FN7I426-TXAW62Y-NB623TQ-GW23CIO-MWVQM7Q-TSFNI42-XEIZ4NM-HLX2PAE";
    "kratail2" = device "JE6KCCC-C4UPRRJ-QKXGGWJ-7VSUSP4-SB4ZMDS-EONA44U-NDMVKAB-74QTDQG";
    "krair" = device "NVYXJFI-XRYR3S3-WLLNMMH-QIOPEHB-5WAB44G-4Y2KE3G-HCFNVNI-Z5QBAQ5";
    "core.tjoda" = device "5WDUBHD-ZWYSK7Z-IQV37HN-ELB2X4X-WOAADCJ-ODUV2FH-BX62TRL-HHAH3AJ";
    "core.terra" = device "EJBC4LG-JL3MYOO-OKUOAT3-UYNIPR2-PXVPQPZ-MHKCCEL-YO3TBLS-52NXVQA";
    "core.oracldn" = device "PODB2YZ-L5ZSWOZ-LJA5SOY-YXW2DKD-WVAOEUL-2DSJH52-I2QP6H5-PDXDVAO";
    "dev.terra" = device "IMAN3KP-YRAZ7OA-OZEXWO2-VALZ6IB-JNLEANA-CHSMUP4-24WNQ33-SXU2MAE";
    "dev.oracfurt" = device "JKYGSCI-JXCDYUM-BPOU6RM-TORXNQE-VFNAKQV-PTTBORO-FEEJIZE-FVQDIAL";
    "dev.ldn" = device "5S3RMNQ-QS6SAJ7-AWGAIW7-BEILMOS-UYHYBCW-EDYSQZA-425UFC2-PVF2BAN";
    "storage.ldn" = device "5IPOAQL-TKKUN7K-DGL26VV-JZGMADN-CCS2M4E-J5UCEJ7-BPQIP7B-W5VNRAN";

    "dev.oracfurt-cooklang" = device "JJTIDK5-36EOH5Y-LJYBN65-S4QDT7X-6IQMP6U-FSDNREU-2EVPA6H-TAFJ6AQ";
  };

  storage = ["krair" "core.tjoda" "core.terra" "dev.ldn" "storage.ldn"];
}
