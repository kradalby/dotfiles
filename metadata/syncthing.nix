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
    "core.tjoda" = device "T77O75Z-XR4MUNF-R6C2AD6-747KQ3X-M4J24YA-YFH3NVC-WDPYMEN-KCH5NAI";
    "core.terra" = device "EJBC4LG-JL3MYOO-OKUOAT3-UYNIPR2-PXVPQPZ-MHKCCEL-YO3TBLS-52NXVQA";
    "core.oracldn" = device "PODB2YZ-L5ZSWOZ-LJA5SOY-YXW2DKD-WVAOEUL-2DSJH52-I2QP6H5-PDXDVAO";
    "dev.terra" = device "IMAN3KP-YRAZ7OA-OZEXWO2-VALZ6IB-JNLEANA-CHSMUP4-24WNQ33-SXU2MAE";
    "dev.oracfurt" = device "5CUHKVK-U5FYJQU-7N7TEMB-QSUOI6M-5NEGQR5-MEFDJHH-DIPVQCD-PBWXWQ4";
    "dev.ldn" = device "YQJMTP4-K6URWRP-S4BMCXI-YWBWOK6-WTLOKTC-5AK5ULJ-MIF3FC5-ML6PTAM";
    "storage.ldn" = device "46SNN77-MYSWKJI-GEOO5HY-RJ6C2I5-YFFX2UQ-RATRH6Q-EKFQHSX-5M5X2AR";
  };

  storage = ["krair" "core.tjoda" "core.terra" "dev.ldn" "storage.ldn"];

  folders = {};
}
