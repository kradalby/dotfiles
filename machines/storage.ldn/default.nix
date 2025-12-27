{
  config,
  pkgs,
  lib,
  ...
}: let
  sshKeys = import ../../metadata/ssh.nix;
in {
  imports = [
    ../../common
    ../../common/incus-vm-ldn.nix
    ../../common/coredns.nix
    ../../common/ddns.nix

    ../../common/tailscale.nix
    ../../common/syncthing-storage.nix

    ./restic.nix
    ./samba.nix
    ./zfs.nix
    # ./dnsmasq.nix  # Config kept, service disabled
  ];

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  services.tailscale.advertiseRoutes = ["10.65.0.0/24"];

  networking = {
    hostName = "storage";
    hostId = "007f0200";
    interfaces."${config.my.lan}" = {
      useDHCP = false;
      ipv4.addresses = [
        {
          address = "10.65.0.28";
          prefixLength = 24;
        }
      ];
      ipv4.routes = [
        {
          address = "10.65.0.1";
          prefixLength = 32;
        }
      ];
    };
  };

  my.users = {
    storage = true;
    timemachine = true;
  };
  my.coredns.bind = ["10.65.0.28"];
  my.ddns = {
    enable = true;
    domains = ["ldn.fap.no"];
  };

  users.users.root.openssh.authorizedKeys.keys = sshKeys.main ++ sshKeys.kradalby ++ sshKeys.work;
  users.users.kradalby.openssh.authorizedKeys.keys = sshKeys.main ++ sshKeys.kradalby ++ sshKeys.work;

  services.attic-watch.enable = false;

  environment.systemPackages = [
    pkgs.docker-client
  ];
}
