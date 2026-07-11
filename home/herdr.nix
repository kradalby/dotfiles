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
}: let
  herdr = "${pkgs.herdr}/bin/herdr";
  fish = "${pkgs.fish}/bin/fish";
  # Panes are spawned by the server, so its env is theirs: profile bin for
  # claude/opencode/ac, plus the usual system paths.
  linuxPath = "${config.home.profileDirectory}/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin";
  darwinPath = "${config.home.profileDirectory}/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin";
in {
  config = lib.mkMerge [
    {
      home.packages = [pkgs.herdr];
      # Make "ac" the default session so a bare `herdr` attaches the herd —
      # resolution order is --session > HERDR_SOCKET_PATH > HERDR_SESSION >
      # default. ac.sh already defaults to "ac", and the server unit pins it.
      home.sessionVariables.HERDR_SESSION = "ac";
    }

    (lib.mkIf pkgs.stdenv.isLinux {
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
          # default_shell is unset (herdr falls back to $SHELL), so pin fish
          # here rather than managing a config.toml herdr also writes to.
          Environment = [
            "PATH=${linuxPath}"
            "HOME=${config.home.homeDirectory}"
            "SHELL=${fish}"
          ];
        };
        Install.WantedBy = ["default.target"];
      };
    })

    (lib.mkIf pkgs.stdenv.isDarwin {
      launchd.agents.herdr = {
        enable = true;
        config = {
          ProgramArguments = [herdr "--session" "ac" "server"];
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
