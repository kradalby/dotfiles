{
  config,
  pkgs,
  lib,
  ...
}:
let
  sshKeys = import ../../metadata/ssh.nix;
in
{
  imports = [
    ../../common/base.nix
    ../../profiles/server.nix
    ../../common/incus-vm-ldn.nix
    ../../common/coredns.nix
    ../../common/ddns.nix

    ../../common/tailscale.nix
    ../../common/syncthing-storage.nix

    ./restic.nix
    ./rest-server.nix
    ./samba.nix
    ./zfs.nix
  ];

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  services.tailscale.advertiseRoutes = [ "10.65.0.0/24" ];
  # Merges with the tag:server baseline from incus-vm-ldn.nix.
  services.tailscale.tags = [
    "tag:backup-client"
    "tag:storage"
  ];

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
  my.coredns.bind = [ "10.65.0.28" ];
  my.ddns = {
    enable = true;
    domains = [ "ldn.fap.no" ];
  };

  users.users.root.openssh.authorizedKeys.keys = sshKeys.main ++ sshKeys.kradalby ++ sshKeys.work;
  users.users.kradalby.openssh.authorizedKeys.keys = sshKeys.main ++ sshKeys.kradalby ++ sshKeys.work;

  environment.systemPackages = [
    # docker_29 client; the default docker-client (28.5.2) is flagged insecure.
    (pkgs.docker_29.override { clientOnly = true; })
  ];
}
