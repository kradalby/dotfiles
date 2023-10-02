{
  pkgs,
  config,
  lib,
  ...
}: let
  sshKeys = import ../metadata/ssh.nix;
in {
  options = {
    my.users = {
      storage = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };

      timemachine = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
    };
  };

  config = {
    # age.secrets.r.file = ../secrets/r.age;
    programs.fish.enable = true;

    security.sudo = {
      enable = true;
      extraRules = [
        {
          commands = [
            {
              command = "${pkgs.systemd}/bin/reboot";
              options = ["NOPASSWD"];
            }
            {
              command = "${pkgs.systemd}/bin/poweroff";
              options = ["NOPASSWD"];
            }
          ];
          groups = ["wheel"];
        }
      ];
    };

    users = {
      users = {
        kradalby = {
          isNormalUser = true;
          uid = 1000;
          extraGroups = ["wireshark" "docker" "wheel"];
          shell = pkgs.fish;
          openssh.authorizedKeys.keys = sshKeys.main ++ sshKeys.kradalby;
          # passwordFile = config.age.secrets.r.path;
        };

        root = {
          openssh.authorizedKeys.keys = sshKeys.main;
          shell = pkgs.fish;
        };

        storage = lib.mkIf config.my.users.storage {
          isSystemUser = true;
          uid = 1992;
          extraGroups = [];
          shell = pkgs.bash;
          group = "storage";
          home = "/storage";
        };

        kristine = lib.mkIf config.my.users.timemachine {
          isNormalUser = true;
          uid = 2500;
          group = "timemachine";
          home = "/storage/timemachine/kristine";
          shell = "/run/current-system/sw/bin/nologin";
          password = "kristine";
        };

        imma = lib.mkIf config.my.users.timemachine {
          isNormalUser = true;
          uid = 2501;
          group = "timemachine";
          home = "/storage/timemachine/imma";
          shell = "/run/current-system/sw/bin/nologin";
          password = "imma";
        };
      };

      groups = {
        storage = lib.mkIf config.my.users.storage {
          gid = 1992;
        };

        timemachine = lib.mkIf config.my.users.timemachine {
          gid = 2500;
        };
      };
    };
  };
}
