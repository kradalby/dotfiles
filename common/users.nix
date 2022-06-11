{ pkgs, config, ... }:
let
  sshKeys = import ../metadata/ssh.nix;
in
{
  age.secrets.r.file = ../secrets/r.age;

  users = {
    users = {
      kradalby = {
        isNormalUser = true;
        uid = 1000;
        extraGroups = [ "wireshark" "docker" ];
        shell = pkgs.fish;
        openssh.authorizedKeys.keys = sshKeys.main ++ sshKeys.kradalby;
        passwordFile = config.age.secrets.r.path;
      };

      root = {
        openssh.authorizedKeys.keys = sshKeys.main;
        # shell = pkgs.zsh;
      };
    };
  };
}
