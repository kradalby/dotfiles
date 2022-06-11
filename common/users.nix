{ pkgs, config, ... }:
let
  keys = [
    # kramacbook
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBV4ZjlUvRDs70qHD/Ldi6OTkFpDEFgfbXbqSnaL2Qup"

    # dev vm
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGyrauaLwnrgeR5mpeOBCw/creVh1dMU1a12TTXvQ+Rd"
  ];

  kradalbyKeys = [
    "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBFiqc4Mou7XVbFNEY0EDkD34G1JbtuFB0WndjktfiBBxS3hz0XdE/mCUjS5Zs65mg5aKzdQXisGRX85LT4DTAtQ= kphone@blink"
  ];
in
{
  age.secrets.r.file = ../secrets/r.age;

  users = {
    users = {
      kradalby = {
        isNormalUser = true;
        uid = 1000;
        extraGroups = [ "audio" "dialout" "lp" "scanner" "video" "wheel" "wireshark" "docker" ];
        shell = pkgs.fish;
        openssh.authorizedKeys.keys = keys ++ kradalbyKeys;
        passwordFile = config.age.secrets.r.path;
      };

      root = {
        openssh.authorizedKeys.keys = keys;
        # shell = pkgs.zsh;
      };
    };
  };
}
