# Standing `ac` agents: role and main-checkout tabs that should always exist in
# rex. Each is a tab in the repo's rex session unless `session` says otherwise.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.my.ac;
  ac = "${import ../pkgs/scripts/ac.nix { inherit pkgs; }}/bin/ac";
  placement = {
    session = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Rex session for the tab; null means the repo's name.";
    };
    tab = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Tab name; null means the role, or \"main\".";
    };
  };
  flags =
    e:
    lib.optionalString (e.session != null) "-s ${lib.escapeShellArg e.session} "
    + lib.optionalString (e.tab != null) "-t ${lib.escapeShellArg e.tab} ";
in
{
  options.my.ac.permagents = lib.mkOption {
    type = lib.types.listOf (
      lib.types.submodule {
        options = placement // {
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
      Long-lived role agents that should always exist, each a Claude tab named
      after the role. Empty by default: only the machine you actually deploy
      from wants these.
    '';
  };

  options.my.ac.mainSessions = lib.mkOption {
    type = lib.types.listOf (
      lib.types.submodule {
        options = placement // {
          repo = lib.mkOption {
            type = lib.types.str;
            description = "Repository name under $GIT_ROOT.";
          };
        };
      }
    );
    default = [ ];
    description = ''
      Repositories that should always have a Claude tab on their main worktree.
      Unlike a permagent: no role, no briefing.
    '';
  };

  config = lib.mkIf (cfg.permagents != [ ] || cfg.mainSessions != [ ]) {
    # A systemd user unit, so a darwin host would accept the options and
    # silently spawn nothing.
    assertions = [
      {
        assertion = pkgs.stdenv.hostPlatform.isLinux;
        message = "my.ac.permagents/mainSessions are Linux-only (systemd user unit)";
      }
    ];

    # ac only opens missing tabs, so a rerun on switch or login leaves running
    # agents alone. `|| true` per entry: one repo missing from disk
    # must not stop the rest.
    systemd.user.services.ac-standing = {
      Unit.Description = "ac — ensure standing agent tabs exist";
      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        # rex autostarts its server from here when none runs, which puts it and
        # every agent in this unit's cgroup. Stopping or restarting the unit
        # must not take them down.
        KillMode = "process";
        ExecStart = pkgs.writeShellScript "ac-standing" (
          lib.concatStringsSep "\n" (
            map (
              a:
              "${ac} ${flags a}permagent ensure ${lib.escapeShellArg a.repo} ${lib.escapeShellArg a.role} || true"
            ) cfg.permagents
            ++ map (m: "${ac} ${flags m}spawn ${lib.escapeShellArg m.repo} || true") cfg.mainSessions
          )
        );
        # Agents inherit an autostarted server's env. /run/wrappers/bin first,
        # per NixOS: without it `sudo` resolves to the non-setuid store symlink.
        Environment = [
          "PATH=/run/wrappers/bin:${config.home.profileDirectory}/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin"
          "HOME=${config.home.homeDirectory}"
          "SHELL=${pkgs.fish}/bin/fish"
        ];
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
