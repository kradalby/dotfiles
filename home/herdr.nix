# herdr server: the single background multiplexer that owns every `ac`
# coding-agent session (one workspace per repo/branch) under the session name
# "ac". `ac` and ac-web drive it over its socket; a human attaches the whole
# herd with `herdr` (or `herdr --session ac`). Running it as its own supervised
# service — rather than letting the first `ac` call spawn a server in its own
# process tree — is what lets those callers come and go without dropping panes.
# Cross-platform: a systemd user unit on Linux, a launchd agent on macOS.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  herdr = "${pkgs.herdr}/bin/herdr";
  fish = "${pkgs.fish}/bin/fish";
  ac = "${import ../pkgs/scripts/ac.nix { inherit pkgs; }}/bin/ac";
  # Panes are spawned by the server, so its env is theirs: profile bin for
  # claude/opencode/ac, plus the usual system paths.
  # /run/wrappers/bin first, per NixOS: without it `sudo` resolves to the
  # non-setuid store symlink in /run/current-system/sw/bin and refuses to run.
  linuxPath = "/run/wrappers/bin:${config.home.profileDirectory}/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin";
  darwinPath = "${config.home.profileDirectory}/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin";
in
{
  options.my.herdr.permagents = lib.mkOption {
    type = lib.types.listOf (
      lib.types.submodule {
        options = {
          repo = lib.mkOption {
            type = lib.types.str;
            description = "Repository name under $GIT_ROOT (e.g. \"dotfiles\").";
          };
          role = lib.mkOption {
            type = lib.types.str;
            description = ''
              Role to run, matching `<repo>/.agents/skills/<role>/SKILL.md`.
            '';
          };
        };
      }
    );
    default = [ ];
    description = ''
      Long-lived role sessions that should always exist in the herdr session.
      Each becomes one workspace named "<repo>:<role>", reconciled once after
      the server starts. Empty by default: only the machine you actually deploy
      from wants these, and a host that merely runs herdr must not spawn them.
    '';
  };

  options.my.herdr.integrations = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [
      "claude"
      "opencode"
    ];
    description = ''
      Agents to install herdr state-detection hooks for. Each runs
      `herdr integration install <agent>` on activation, which drops a hook
      and registers it in that agent's (mutable) config. Valid names: claude,
      codex, opencode, and the rest herdr supports.
    '';
  };

  config = lib.mkMerge [
    {
      home.packages = [ pkgs.herdr ];
      # Make "ac" the default session so a bare `herdr` attaches the herd —
      # resolution order is --session > HERDR_SOCKET_PATH > HERDR_SESSION >
      # default. ac.sh already defaults to "ac", and the server unit pins it.
      home.sessionVariables.HERDR_SESSION = "ac";

      # The herdr agent skill, pinned from the flake input (no vendoring). It
      # gates on HERDR_ENV=1, so it only activates for an agent running inside
      # a herdr pane — teaching it to drive herdr's socket API.
      home.file.".claude/skills/herdr/SKILL.md".source = pkgs.herdr-skill;

      # Install per-agent state hooks so herdr reports precise agent status
      # (blocked/working/idle/done) instead of guessing. Runs after mutableJson
      # so the agents' writable configs exist; idempotent, so it self-heals and
      # tracks the herdr version. `|| true`: a missing agent must not fail switch.
      home.activation.herdrIntegrations = lib.hm.dag.entryAfter [ "writeBoundary" "mutableJson" ] (
        lib.concatMapStringsSep "\n" (
          a: "run ${herdr} integration install ${a} || true"
        ) config.my.herdr.integrations
      );
    }

    (lib.mkIf (config.my.herdr.permagents != [ ]) {
      # The reconcile below is a systemd user unit, so a darwin host would
      # accept the option and silently spawn nothing.
      assertions = [
        {
          assertion = pkgs.stdenv.hostPlatform.isLinux;
          message = "my.herdr.permagents is Linux-only (systemd user unit)";
        }
      ];
    })

    (lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      systemd.user.services.herdr = {
        Unit.Description = "herdr — agent multiplexer server (session: ac)";
        Service = {
          Type = "simple";
          ExecStart = "${herdr} --session ac server";
          ExecStop = "${herdr} --session ac server stop";
          # On-failure only: a restart kills every pane (like a reboot), so we
          # don't want it cycling for anything but a genuine crash.
          Restart = "on-failure";
          RestartSec = 5;
          KillSignal = "SIGTERM";
          TimeoutStopSec = 15;
          # Panes inherit this. 100 is the floor — lower is silently clamped,
          # since dropping below the user manager needs CAP_SYS_RESOURCE.
          OOMScoreAdjust = 100;
          # default_shell is unset (herdr falls back to $SHELL), so pin fish
          # here rather than managing a config.toml herdr also writes to.
          Environment = [
            "PATH=${linuxPath}"
            "HOME=${config.home.homeDirectory}"
            "SHELL=${fish}"
          ];
        };
        Install.WantedBy = [ "default.target" ];
      };

      # Reconcile the declared role sessions once the server is up. A oneshot,
      # not a supervised service: herdr owns the agent processes, so all this
      # has to do is notice a missing workspace and create it. `ac permagent
      # ensure` is idempotent, so re-running it on every login is a no-op.
      # `|| true` per entry: one repo missing from disk must not stop the rest.
      systemd.user.services.herdr-permagents = lib.mkIf (config.my.herdr.permagents != [ ]) {
        Unit = {
          Description = "herdr — ensure declared role sessions exist";
          After = [ "herdr.service" ];
          Requires = [ "herdr.service" ];
        };
        Service = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = pkgs.writeShellScript "herdr-permagents" (
            lib.concatMapStringsSep "\n" (
              a: "${ac} permagent ensure ${lib.escapeShellArg a.repo} ${lib.escapeShellArg a.role} || true"
            ) config.my.herdr.permagents
          );
          Environment = [
            "PATH=${linuxPath}"
            "HOME=${config.home.homeDirectory}"
            "SHELL=${fish}"
          ];
        };
        Install.WantedBy = [ "default.target" ];
      };
    })

    (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
      launchd.agents.herdr = {
        enable = true;
        config = {
          ProgramArguments = [
            herdr
            "--session"
            "ac"
            "server"
          ];
          RunAtLoad = true;
          # Respawn only on a crash: a clean `server stop` (exit 0) stays down,
          # and a restart would drop every pane anyway.
          KeepAlive.SuccessfulExit = false;
          ProcessType = "Background";
          EnvironmentVariables = {
            PATH = darwinPath;
            HOME = config.home.homeDirectory;
            SHELL = fish;
          };
          StandardOutPath = "${config.home.homeDirectory}/Library/Logs/herdr.log";
          StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/herdr-error.log";
        };
      };
    })
  ];
}
