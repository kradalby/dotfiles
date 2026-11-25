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
  setec = config.services.setec-secrets;

  # Reads the file on every call, so git works in units with no login
  # environment and a rotated token needs no restart. Silent when the file is
  # missing, so the next helper (gh) answers.
  gitCredential = pkgs.writeShellScript "git-credential-setec" ''
    [ "$1" = get ] && [ -r ${setec.github-token.path} ] || exit 0
    echo username=x-access-token
    echo "password=$(cat ${setec.github-token.path})"
  '';

  githubHttps =
    owner:
    lib.nameValuePair "https://github.com/${owner}/" rec {
      insteadOf = [
        "git@github.com:${owner}/"
        "ssh://git@github.com/${owner}/"
        # git does not rewrite twice, so home/git.nix's gh: alias needs its own entry.
        "gh:${owner}/"
      ];
      pushInsteadOf = insteadOf;
    };
in
{
  options.my.dev.claudeLogin = lib.mkEnableOption ''
    an interactive Claude `/login` on this host instead of the shared yearly
    token. The token cannot do Remote Control or claude.ai connectors, and
    wins over a login when set
  '';

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

  config = {
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

    services.setec-secrets = {
      github-token = {
        secret = "github/kradalby/dev-token";
        owner = "kradalby";
      };
      atuin-username = {
        secret = "atuin/kradalby/username";
        owner = "kradalby";
      };
      atuin-password = {
        secret = "atuin/kradalby/password";
        owner = "kradalby";
      };
      atuin-key = {
        secret = "atuin/kradalby/key";
        owner = "kradalby";
      };
      claude-token = lib.mkIf (!config.my.dev.claudeLogin) {
        secret = "claude/kradalby/oauth-token";
        owner = "kradalby";
      };
    };

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

      # No SSH key for GitHub on the herd: these owners go over HTTPS with the
      # setec token. Other owners keep SSH and need a key on the host.
      programs.gh.gitCredentialHelper.enable = false;
      programs.git.settings = {
        url = lib.listToAttrs (
          map githubHttps [
            "kradalby"
            "juanfont"
          ]
        );
        credential = lib.genAttrs [ "https://github.com" "https://gist.github.com" ] (_: {
          helper = [
            "" # drop inherited helpers
            "${gitCredential}"
            "${lib.getExe pkgs.gh} auth git-credential"
          ];
        });
      };

      # A host with its own `gh auth login` keeps it.
      home.sessionVariablesExtra = ''
        if [ ! -e "$HOME/.config/gh/hosts.yml" ] && [ -r ${setec.github-token.path} ]; then
          export GH_TOKEN="$(cat ${setec.github-token.path})"
        fi
      ''
      + lib.optionalString (!config.my.dev.claudeLogin) ''
        if [ -r ${setec.claude-token.path} ]; then
          export CLAUDE_CODE_OAUTH_TOKEN="$(cat ${setec.claude-token.path})"
        fi
      '';

      # The secrets land a few minutes after first boot, hence the retry.
      systemd.user.services.atuin-login = {
        Unit.Description = "Log atuin in with the shared account";
        Service = {
          Type = "oneshot";
          Restart = "on-failure";
          RestartSec = 60;
          ExecStart = pkgs.writeShellScript "atuin-login" ''
            atuin=${lib.getExe pkgs.atuin}
            "$atuin" status 2>/dev/null | grep -q '^Username:' && exit 0
            exec "$atuin" login \
              -u "$(cat ${setec.atuin-username.path})" \
              -p "$(cat ${setec.atuin-password.path})" \
              -k "$(cat ${setec.atuin-key.path})"
          '';
        };
        Install.WantedBy = [ "default.target" ];
      };

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
  };
}
