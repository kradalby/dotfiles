{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  sshKeys = import ../../metadata/ssh.nix;
  wireguardHosts = import ../../metadata/wireguard.nix {inherit lib config;};
  wireguardConfig = wireguardHosts.clients.ldn;
in {
  imports = [
    ../../common
    # Import incus.nix directly instead of incus-vm-ldn.nix to avoid
    # the services.tailscale.tags setting which conflicts with the new
    # upstream Tailscale NixOS module.
    ../../common/incus.nix

    ../../common/containers.nix

    # common/tailscale.nix is NOT imported here; the new upstream module
    # from tailscale.nixosModules.default (added in flake.nix) replaces it.

    inputs.ssh-agent-mux.nixosModules.default

    ./restic.nix
  ];

  # The new upstream Tailscale module defines services.tailscale as a
  # submodule with a built-in `services` option. Our custom
  # tailscale-services.nix declares a conflicting option at the same path.
  # Disable it here; the new module handles serve config natively.
  disabledModules = [
    ../../modules/tailscale-services.nix
  ];

  # Inlined from common/incus-vm-ldn.nix (networking parts only;
  # services.tailscale.tags is handled via extraUpFlags below).
  networking = {
    hostName = "dev";
    domain = "ldn.fap.no";
    nameservers = ["10.65.0.1"];
    defaultGateway = {
      address = "10.65.0.1";
      interface = config.my.lan;
    };
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

  boot.tmp.tmpfsSize = "4G";

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

  age.secrets.nix-push-key = {
    file = ../../secrets/nix-push-key.age;
  };
  services.nix-push = {
    enable = true;
    sshKeyFile = config.age.secrets.nix-push-key.path;
  };

  # Headscale pre-auth keys
  age.secrets.headscale-client-preauthkey = {
    file = ../../secrets/headscale-client-preauthkey.age;
  };
  age.secrets.headscale-sfiber-client-preauthkey = {
    file = ../../secrets/headscale-sfiber-client-preauthkey.age;
  };

  # Primary Tailscale instance: kradalby.no tailnet (upstream SaaS)
  # TUN mode with full routing features (exit node, subnet router, connector).
  services.tailscale = {
    enable = true;
    authKeyFile = config.age.secrets.tailscale-preauthkey.path;
    useRoutingFeatures = "both";
    extraSetFlags =
      [
        "--ssh=true"
        "--accept-dns=true"
        "--advertise-exit-node"
        "--advertise-connector"
        "--webclient=true"
        "--hostname=dev-ldn"
      ]
      ++ lib.optional ((builtins.length wireguardConfig.additional_networks) > 0)
      "--advertise-routes=${builtins.concatStringsSep "," wireguardConfig.additional_networks}";
    extraUpFlags = [
      "--advertise-tags=tag:ldn,tag:gateway,tag:server"
    ];
  };

  # Secondary Tailscale instance: headscale.kradalby.no
  # Userspace networking (no TUN conflicts with the primary instance).
  services.tailscales.headscale = {
    enable = true;
    authKeyFile = config.age.secrets.headscale-client-preauthkey.path;
    extraUpFlags = ["--login-server=https://headscale.kradalby.no"];
    extraSetFlags = ["--hostname=dev-ldn"];
  };

  # Secondary Tailscale instance: headscale.sandefjordfiber.no
  # Userspace networking (no TUN conflicts with the primary instance).
  services.tailscales.sfiber = {
    enable = true;
    authKeyFile = config.age.secrets.headscale-sfiber-client-preauthkey.path;
    extraUpFlags = ["--login-server=https://headscale.sandefjordfiber.no"];
    extraSetFlags = ["--hostname=dev-ldn"];
  };

  services.ssh-agent-mux = {
    enable = true;
    watchForSSHForward = true;
    logLevel = "debug";
  };

  zramSwap = {
    enable = true;
    memoryPercent = 25;
  };

  swapDevices = lib.mkForce [
    {
      device = "/swapfile";
      size = 8192;
    }
  ];

  environment.systemPackages = [
    # Do install the docker CLI to talk to podman.
    # Not needed when virtualisation.docker.enable = true;
    pkgs.docker-client
    pkgs.unstable.lima
    pkgs.nodejs_24
  ];

  home-manager.users.kradalby = {
    programs.git.settings = {
      commit.gpgsign = true;
      gpg.format = "ssh";
      "gpg \"ssh\"".allowedSignersFile = "~/.ssh/allowed_signers";
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
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?
}
