{ pkgs, ... }:
let
  keys = [
    # kramacbook
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBV4ZjlUvRDs70qHD/Ldi6OTkFpDEFgfbXbqSnaL2Qup"

    # dev vm
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGyrauaLwnrgeR5mpeOBCw/creVh1dMU1a12TTXvQ+Rd"
  ];
in
{
  users = {
    users = {
      kradalby = {
        isNormalUser = true;
        uid = 1000;
        extraGroups = [ "audio" "dialout" "lp" "scanner" "video" "wheel" "wireshark" ];
        shell = pkgs.fish;
        openssh.authorizedKeys.keys = keys;
      };

      root = {
        openssh.authorizedKeys.keys = keys;
        shell = pkgs.zsh;
      };
    };
  };
}

