{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  sshKeys = import ../../metadata/ssh.nix;
in {
  imports = [
    ../../common
    ../../common/incus-vm-ldn.nix

    ../../common/containers.nix

    ../../common/tailscale.nix
    inputs.ssh-agent-mux.nixosModules.default

    ./restic.nix
  ];

  networking = {
    hostName = "dev";
    interfaces."${config.my.lan}" = {
      useDHCP = false;
      ipv4.addresses = [
        {
          address = "10.65.0.27";
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

    # Disabled - no longer have WAN interface
    # "net.ipv6.conf.${config.my.wan}.accept_ra" = 2;
    # "net.ipv6.conf.${config.my.wan}.autoconf" = 1;
  };

  # Also add work SSH keys
  users.users.root.openssh.authorizedKeys.keys = sshKeys.main ++ sshKeys.kradalby ++ sshKeys.work;
  users.users.kradalby.openssh.authorizedKeys.keys = sshKeys.main ++ sshKeys.kradalby ++ sshKeys.work;
  users.users.kradalby.linger = true;

  # age.secrets.nix-push-key = {
  #   file = ../../secrets/nix-push-key.age;
  # };
  # services.nix-push = {
  #   enable = true;
  #   sshKeyFile = config.age.secrets.nix-push-key.path;
  # };

  services.tailscale = let
    wireguardHosts = import ../../metadata/wireguard.nix {inherit lib config;};
    wireguardConfig = wireguardHosts.clients.ldn;
  in {
    advertiseRoutes = wireguardConfig.additional_networks;
    tags = ["tag:ldn" "tag:gateway" "tag:server"];
  };

  services.ssh-agent-mux = {
    enable = true;
    watchForSSHForward = true;
    logLevel = "debug";
  };

  environment.systemPackages = [
    # Do install the docker CLI to talk to podman.
    # Not needed when virtualisation.docker.enable = true;
    pkgs.docker-client
    pkgs.unstable.lima
    pkgs.nodejs_24
  ];

  home-manager.users.kradalby = {
    systemd.user.services.opencode-serve = {
      Unit = {
        Description = "OpenCode serve";
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.opencode}/bin/opencode serve --hostname 0.0.0.0";
        Restart = "always";
        RestartSec = 15;
        WorkingDirectory = "/home/kradalby";
      };
      Install = {
        WantedBy = ["default.target"];
      };
    };
  };

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
