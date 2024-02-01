{
  config,
  flakes,
  pkgs,
  lib,
  ...
}: let
  sshKeys = import ../../metadata/ssh.nix;
in {
  imports = [
    ../../common
    ./hardware-configuration.nix

    ../../common/acme.nix
    ../../common/nginx.nix
    ../../common/containers.nix

    # ../../common/coredns.nix
    ../../common/consul.nix

    ./restic.nix
    ./tailscale.nix
    ./tailscale-headscale.nix
    ./nvidia.nix
    # ./syncthing.nix
  ];

  my.wan = "enp3s0";
  my.lan = "enp4s0";

  age.secrets.ldn-wifi = {
    file = ../../secrets/ldn-wifi.age;
  };

  networking = {
    hostId = "58808be0";
    hostName = "dev";
    domain = "ldn.fap.no";
    nameservers = [
      "1.1.1.1"
      "1.0.0.1"
    ];
    usePredictableInterfaceNames = lib.mkForce true;
    interfaces = {
      "${config.my.wan}" = {
        useDHCP = true;
      };

      "${config.my.lan}" = {
        useDHCP = true;
      };

      "wlp0s20f3" = {
        useDHCP = true;
      };
    };

    wireless = {
      enable = true;
      environmentFile = config.age.secrets.ldn-wifi.path;
      networks = {
        "_kad".psk = "@PSK_UNDERSCORE_KAD@";
      };
    };

    nat = {
      enable = true;
      externalInterface = config.my.wan;
      # internalIPs = [ "10.0.0.0/8" ];
      # internalInterfaces = [ config.my.lan "iot" ];
      # forwardPorts = [
      #   {
      #     sourcePort = 64322;
      #     destination = "10.67.0.1:22";
      #     proto = "tcp";
      #   }
      #   {
      #     sourcePort = 500;
      #     destination = "10.67.0.1:51820";
      #     proto = "udp";
      #   }
      #   {
      #     sourcePort = 4500;
      #     destination = "10.67.0.1:51820";
      #     proto = "udp";
      #   }
      # ];
    };

    firewall = {
      enable = lib.mkForce true;
      # This is a special override for gateway machines as we
      # dont want to use "openFirewall" here since it makes
      # everything world available.
      allowedTCPPorts = lib.mkForce [
        22 # SSH
        80 # HTTP
        443 # HTTPS
      ];

      allowedUDPPorts = lib.mkForce [
        443 # HTTPS
        config.services.tailscale.port
        # config.networking.wireguard.interfaces.wg0.listenPort
      ];

      trustedInterfaces = [config.my.lan "podman+"];
    };
  };

  # Also add work SSH keys
  users.users.root.openssh.authorizedKeys.keys = sshKeys.main ++ sshKeys.kradalby ++ sshKeys.work;
  users.users.kradalby.openssh.authorizedKeys.keys = sshKeys.main ++ sshKeys.kradalby ++ sshKeys.work;

  virtualisation = {
    oci-containers.backend = lib.mkForce "podman";
    docker.enable = false;
    podman = {
      enable = true;
      dockerSocket.enable = true;
      defaultNetwork.settings = {
        subnets = [
          {
            gateway = "172.16.0.1";
            subnet = "172.16.0.0/12";
          }
        ];
        dns_enabled = true;
      };
    };
  };
  environment.systemPackages = [
    # Do install the docker CLI to talk to podman.
    # Not needed when virtualisation.docker.enable = true;
    pkgs.docker-client
  ];
  users.users.kradalby.extraGroups = ["podman"];

  security.sudo.extraRules = [
    {
      users = ["kradalby"];
      commands = [
        {
          command = "ALL";
          options = ["NOPASSWD"]; # "SETENV" # Adding the following could be a good idea
        }
      ];
    }
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "20.09"; # Did you read the comment?
}
