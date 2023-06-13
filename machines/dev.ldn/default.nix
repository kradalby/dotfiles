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

    ../../common/coredns.nix
    ../../common/consul.nix

    # ./restic.nix
    ./tailscale.nix
    # ./syncthing.nix
  ];

  my.wan = "enp2s0";
  my.lan = "enp3s0";

  age.secrets.ldn-wifi = {
    file = ../../secrets/ldn-wifi.age;
  };

  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking = {
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

      trustedInterfaces = [config.my.lan];
    };
  };

  # Also add work SSH keys
  users.users.root.openssh.authorizedKeys.keys = sshKeys.main ++ sshKeys.kradalby ++ sshKeys.work;
  users.users.kradalby.openssh.authorizedKeys.keys = sshKeys.main ++ sshKeys.kradalby ++ sshKeys.work;

  virtualisation.docker.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "20.09"; # Did you read the comment?
}
