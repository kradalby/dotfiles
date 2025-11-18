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

    ../../common/acme.nix
    ../../common/nginx.nix
    ../../common/containers.nix

    ../../common/consul.nix
    ../../common/tailscale.nix

    ./restic.nix
    ./samba.nix
    # ./dnsmasq.nix  # Config kept, service disabled
  ];

  networking = {
    hostName = "storage";
    interfaces."${config.my.lan}".useDHCP = true;
  };

  my.users = {
    storage = true;
    timemachine = true;
  };

  users.users.root.openssh.authorizedKeys.keys = sshKeys.main ++ sshKeys.kradalby ++ sshKeys.work;
  users.users.kradalby.openssh.authorizedKeys.keys = sshKeys.main ++ sshKeys.kradalby ++ sshKeys.work;

  services.attic-watch.enable = false;

  environment.systemPackages = [
    pkgs.docker-client
  ];
}
