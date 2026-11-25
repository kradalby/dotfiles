# Dev machine profile: a box where kradalby and a herd of coding agents work.
# Site-free on purpose; the host file brings the platform module, the network,
# its routes, and buildOnTarget in flake.nix (agents build locally).
{
  config,
  pkgs,
  lib,
  ...
}:
let
  sshKeys = import ../../metadata/ssh.nix;
  hostname = builtins.replaceStrings [ ".fap.no" "." ] [ "" "-" ] config.networking.fqdn;
in
{
  imports = [
    ../../common/base.nix
    ../server.nix

    # Interactive userland (editor, shell tools) comes via home-manager
    # (pkgs/home-packages.nix); tmux + its config come via common/base.nix.
    ../../common/containers.nix

    ../../common/tailscale.nix
    ../../common/tsnixcache-client.nix

    ./restic.nix
    ./syncthing.nix
    ./ac-web.nix
    ./codex-remote-control.nix
  ];

  boot.tmp.tmpfsSize = "7G";

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
  };

  # Also add work SSH keys
  users.users.root.openssh.authorizedKeys.keys = sshKeys.main ++ sshKeys.kradalby ++ sshKeys.work;
  users.users.kradalby.openssh.authorizedKeys.keys = sshKeys.main ++ sshKeys.kradalby ++ sshKeys.work;
  users.users.kradalby.linger = true;

  services.tailscale.tags = [
    "tag:backup-client"
    "tag:dev"
    "tag:gateway"
  ];

  # Secondary Tailscale instance: headscale.sandefjordfiber.no.
  # Userspace networking (no TUN conflicts with the primary instance).
  age.secrets.headscale-sfiber-client-preauthkey = {
    file = ../../secrets/headscale-sfiber-client-preauthkey.age;
  };
  services.tailscales.sfiber = {
    enable = true;
    authKeyFile = config.age.secrets.headscale-sfiber-client-preauthkey.path;
    extraUpFlags = [ "--login-server=https://headscale.sandefjordfiber.no" ];
    extraSetFlags = [
      "--hostname=${hostname}"
      # Routes advertised on the sfiber tailnet are unreachable without this.
      "--accept-routes=true"
    ];
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
    (pkgs.docker_29.override { clientOnly = true; })
    pkgs.unstable.lima-full
    pkgs.nodejs_26
    pkgs.incus
  ];

  home-manager.users.kradalby = {
    imports = [
      ../../home/ac.nix
      ../../home/atuin.nix
    ];
    my.atuin.enable = true; # personal account (shared with krair)

    my.packages.ai.codex = true;

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

  nix.settings = {
    # Above the fleet default: many concurrent agent builds can consume the
    # gap between the two thresholds faster than the daemon collects, and a
    # collection that fires mid-build fails it ("failed to obtain
    # derivation"), so both must clear a full closure rebuild.
    min-free = 30 * 1024 * 1024 * 1024;
    max-free = 100 * 1024 * 1024 * 1024;

    # Defaults are cores = 0 and max-jobs = auto: one derivation may claim
    # every core and as many may run at once. That is memory demand nothing on
    # the dispatch side can restrain, on a box that is also an interactive
    # workstation running the agent herd.
    cores = 4;
    max-jobs = 4;
  };

  # Builders inherit this, so they get OOM-killed before the herd's panes (100).
  systemd.services.nix-daemon.serviceConfig.OOMScoreAdjust = 500;

  # Swap sits full here, so page cache is all that is left to reclaim, and
  # evicting it means re-reading every running binary: the box stalls while
  # earlyoom's default 10% still counts that cache as available.
  services.earlyoom.freeMemThreshold = 15;
}
