{
  config,
  pkgs,
  lib,
  inputs,
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

    # Interactive userland (editor, shell tools) comes via home-manager
    # (pkgs/home-packages.nix); tmux + its config come via common/base.nix.
    ../../common/containers.nix

    ../../common/tailscale.nix
    ../../common/tsnixcache-client.nix

    inputs.ssh-agent-mux.nixosModules.default

    ./restic.nix
    ./syncthing.nix
    ./ac-web.nix
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

  boot.tmp.tmpfsSize = "7G";

  # Build aarch64-linux here (qemu emulation) so `rnb dev.ldn` can serve arm
  # builds; binfmt auto-advertises it via extra-platforms. Slow but handy.
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

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

  services.tailscale = {
    # 192.168.156.0/24 = the IoT VLAN (unifi vlan 156); routed here so
    # core.oracldn's tasmota/homewizard exporters can reach *.ldn devices.
    # Needs the unifi LAN->IoT firewall to permit the probe.
    advertiseRoutes = [
      "10.65.0.0/16"
      "192.168.156.0/24"
      "2a02:6b66:7019::/64"
    ];
    # tag:server comes from the incus-vm-ldn.nix baseline.
    tags = [
      "tag:backup-client"
      "tag:deployer"
      "tag:dev"
      "tag:gateway"
    ];
  };

  # Secondary Tailscale instance: headscale.sandefjordfiber.no (dev.ldn only).
  # Userspace networking (no TUN conflicts with the primary instance).
  age.secrets.headscale-sfiber-client-preauthkey = {
    file = ../../secrets/headscale-sfiber-client-preauthkey.age;
  };
  services.tailscales.sfiber = {
    enable = true;
    authKeyFile = config.age.secrets.headscale-sfiber-client-preauthkey.path;
    extraUpFlags = [ "--login-server=https://headscale.sandefjordfiber.no" ];
    extraSetFlags = [
      "--hostname=dev-ldn"
      # Routes advertised on the sfiber tailnet are unreachable without this.
      "--accept-routes=true"
    ];
  };

  services.ssh-agent-mux = {
    enable = true;
    watchForSSHForward = true;
    logLevel = "debug";
  };

  # Eternal Terminal — testing alongside mosh. Unlike mosh it forwards the raw
  # byte stream (TCP), so native scrollback + mouse survive the link, which boo
  # sessions need. Exposed on the tailnet only.
  services.eternal-terminal.enable = true;
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    config.services.eternal-terminal.port
  ];

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
    (pkgs.docker_29.override { clientOnly = true; })
    pkgs.unstable.lima-full
    pkgs.nodejs_26
    pkgs.incus
  ];

  home-manager.users.kradalby = {
    imports = [
      ../../home/herdr.nix
      ../../home/atuin.nix
    ];
    my.atuin.enable = true; # personal account (shared with krair)

    my.packages.ai.codex = true;
    # Default is claude+opencode; codex needs its own state hook or herdr
    # cannot tell idle from working in a codex pane.
    my.herdr.integrations = [
      "claude"
      "codex"
      "opencode"
    ];

    # This is the box the fleet is deployed from, so it is the one that wants
    # a standing deploy agent per repo. Each is briefed from that repo's own
    # .agents/skills/deploy/SKILL.md, so the rules live with the thing they
    # deploy.
    my.herdr.permagents = [
      {
        repo = "dotfiles";
        role = "deploy";
      }
      {
        repo = "sfiber";
        role = "deploy";
      }
    ];

    # infrastructure has no deploy role — tofu is applied by hand, per module —
    # but it is worked on continuously, so keep its main session standing.
    my.herdr.mainSessions = [ "infrastructure" ];

    programs.git.settings = {
      commit.gpgsign = true;
      gpg.format = "ssh";
      "gpg \"ssh\"".allowedSignersFile = "~/.ssh/allowed_signers";
    };

    my.agents.extraInstructions = builtins.readFile ./agents.md;

    # Go trims its build cache at 5 days with no size cap, and every worktree
    # the herd builds adds its own entries, so it outgrows the disk. Go
    # refreshes an entry's mtime on use, so age by mtime is safe mid-build.
    systemd.user.services.go-build-trim = {
      Unit = {
        Description = "Trim Go build cache entries unused for a day";
        ConditionPathIsDirectory = "%h/.cache/go-build";
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.findutils}/bin/find %h/.cache/go-build -type f -mmin +1440 -delete";
        Nice = 19;
        IOSchedulingClass = "idle";
      };
    };
    systemd.user.timers.go-build-trim = {
      Unit.Description = "Daily Go build cache trim";
      Timer = {
        OnCalendar = "daily";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };

  security.sudo.extraRules = [
    {
      users = [ "kradalby" ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ]; # "SETENV"
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

  # nixos-raspberrypi prebuilt kernel/firmware. Scoped here, not fleet-wide:
  # trusting the key lets that cache substitute any path, so only hosts that
  # actually build rpi closures carry it.
  nix.settings = {
    substituters = [ "https://nixos-raspberrypi.cachix.org" ];
    trusted-public-keys = [
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];

    # Above the fleet default: many concurrent agent builds can consume the
    # gap between the two thresholds faster than the daemon collects, and a
    # collection that fires mid-build fails it ("failed to obtain
    # derivation"), so both must clear a full closure rebuild.
    min-free = 30 * 1024 * 1024 * 1024;
    max-free = 100 * 1024 * 1024 * 1024;

    # Defaults are cores = 0 and max-jobs = auto: one derivation may claim all
    # 16 cores and 16 may run at once. That is memory demand nothing on the
    # dispatch side can restrain, and it lands on the one box that is also an
    # interactive workstation running the agent herd. 4 x 4 fits the core count
    # with the herd's panes still schedulable.
    cores = 4;
    max-jobs = 4;
  };

  # Builders inherit this, so they get OOM-killed before the herd's panes (100).
  systemd.services.nix-daemon.serviceConfig.OOMScoreAdjust = 500;
}
