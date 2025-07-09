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
    ./hardware-configuration.nix

    ../../common/acme.nix
    ../../common/nginx.nix
    ../../common/containers.nix

    ../../common/consul.nix
    ../../common/ddns.nix
    # ../../common/smokeping-exporter.nix
    ../../common/miniupnp.nix
    ../../common/tailscale.nix
    ../../modules/microvm-host.nix

    ./restic.nix
    ./tailscale-headscale.nix
    ./nvidia.nix
    ./wireguard.nix
    ./corerad.nix
    ./dnsmasq.nix
    ./avahi.nix
    ./networking.nix
    ./nft.nix
    ./samba.nix
    ./zfs.nix
    ./syncthing.nix
    ./coredns.nix
  ];

  my = {
    wan = "wan0";
    lan = "lanbr0";

    users.storage = true;
    users.timemachine = true;
  };


  boot.kernel.sysctl = {
    # if you use ipv4, this is all you need
    "net.ipv4.conf.all.forwarding" = true;

    # If you want to use it for ipv6
    "net.ipv6.conf.all.forwarding" = true;

    # source: https://github.com/mdlayher/homelab/blob/master/nixos/routnerr-2/configuration.nix#L52
    # By default, not automatically configure any IPv6 addresses.
    "net.ipv6.conf.all.accept_ra" = 0;
    "net.ipv6.conf.all.autoconf" = 0;
    "net.ipv6.conf.all.use_tempaddr" = 0;

    # On WAN, allow IPv6 autoconfiguration and tempory address use.
    "net.ipv6.conf.${config.my.wan}.accept_ra" = 2;
    "net.ipv6.conf.${config.my.wan}.autoconf" = 1;
  };

  # Also add work SSH keys
  users.users.root.openssh.authorizedKeys.keys = sshKeys.main ++ sshKeys.kradalby ++ sshKeys.work;
  users.users.kradalby.openssh.authorizedKeys.keys = sshKeys.main ++ sshKeys.kradalby ++ sshKeys.work;

  # Temporarily disabled - attic server is not currently running
  services.attic-watch.enable = false;

  services.tailscale = let
    wireguardHosts = import ../../metadata/wireguard.nix;
    wireguardConfig = wireguardHosts.clients.ldn;
  in {
    advertiseRoutes = wireguardConfig.additional_networks;
    tags = ["tag:ldn" "tag:gateway" "tag:server"];
  };

  environment.systemPackages = [
    # Do install the docker CLI to talk to podman.
    # Not needed when virtualisation.docker.enable = true;
    pkgs.docker-client
  ];

  security.sudo.extraRules = [
    {
      users = ["kradalby"];
      commands = [
        {
          command = "ALL";
          options = ["NOPASSWD"]; # "SETENV"
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
  system.stateVersion = "24.05"; # Did you read the comment?
}
