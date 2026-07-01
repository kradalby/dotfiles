{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.services.claude-code;

  resolvePath = p:
    if lib.hasPrefix "~/" p
    then "${config.home.homeDirectory}/${lib.removePrefix "~/" p}"
    else p;

  mkArgs = name: ic: let
    instanceName =
      if ic.name == ""
      then name
      else ic.name;
    instancePrefix =
      if ic.prefix == ""
      then name
      else ic.prefix;
  in
    [
      "${ic.package}/bin/claude"
      "remote-control"
      "--name"
      instanceName
      "--remote-control-session-name-prefix"
      instancePrefix
      "--spawn"
      ic.spawn
    ]
    ++ lib.optionals (ic.spawn != "session") ["--capacity" (toString ic.capacity)]
    ++ lib.optional ic.verbose "--verbose"
    ++ lib.optional (! ic.createSessionInDir) "--no-create-session-in-dir"
    ++ [
      (
        if ic.sandbox
        then "--sandbox"
        else "--no-sandbox"
      )
    ];

  enabled = lib.filterAttrs (_: ic: ic.enable) cfg;

  # Rewrite each builder repo's origin remote to a real URL. Repos cloned via an
  # insteadOf alias (e.g. `gh:`) store the alias in remote.origin.url; the bridge
  # registers it verbatim and the API rejects new-session creation with 400 ("The
  # request was invalid"). `get-url` expands the alias; a real URL is a no-op.
  # Done at activation, not in ExecStart, so builders restart only on a real
  # version/config change — never on an incidental git or bash bump.
  normalizeRemotes =
    lib.concatMapStringsSep "\n" (ic: let
      dir = lib.escapeShellArg (resolvePath ic.path);
    in ''
      if ${pkgs.git}/bin/git -C ${dir} rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        u="$(${pkgs.git}/bin/git -C ${dir} remote get-url origin 2>/dev/null || true)"
        [ -n "$u" ] && ${pkgs.git}/bin/git -C ${dir} remote set-url origin "$u" || true
      fi
    '') (lib.attrValues enabled);
in {
  imports = [
    ./linux.nix
    ./darwin.nix
  ];

  options.services.claude-code = lib.mkOption {
    default = {};
    description = "Multiple `claude remote-control` instances, one user service (systemd on Linux, launchd on Darwin) per attribute.";
    type = lib.types.attrsOf (lib.types.submodule ({name, ...}: {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to run a remote-control server for this instance.";
        };

        path = lib.mkOption {
          type = lib.types.str;
          example = "~/git/dotfiles";
          description = "Working directory for the remote-control server. `~/` is expanded to the user's home.";
        };

        name = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "Value passed to `--name`. Defaults to the attribute name.";
        };

        prefix = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "Value passed to `--remote-control-session-name-prefix`. Defaults to the attribute name.";
        };

        spawn = lib.mkOption {
          type = lib.types.enum ["same-dir" "worktree" "session"];
          default = "same-dir";
          description = "Spawn mode passed to `--spawn`.";
        };

        capacity = lib.mkOption {
          type = lib.types.ints.positive;
          default = 32;
          description = "Max concurrent sessions. Ignored when `spawn = \"session\"`.";
        };

        verbose = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Pass `--verbose`.";
        };

        createSessionInDir = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Pre-create a session in the working dir on start (claude's
            `--[no-]create-session-in-dir`). Must stay ON: the anchor session
            is what gives the environment a stable identity, so a restart
            *resumes* the same env (one builder per instance in claude.ai/code,
            sessions restored across new versions). With `--no-create-session-in-dir`
            every restart mints a fresh env, flooding the picker with dead
            duplicates and losing in-flight sessions.
          '';
        };

        sandbox = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "If true pass `--sandbox`, otherwise pass `--no-sandbox`.";
        };

        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.master.claude-code;
          defaultText = lib.literalExpression "pkgs.master.claude-code";
          description = "Package providing the `claude` binary.";
        };
      };
    }));
  };

  config = {
    _module.args.claudeCodeLib = {
      inherit resolvePath mkArgs enabled;
    };

    home.activation = lib.mkIf (enabled != {}) {
      claudeNormalizeRemotes = lib.hm.dag.entryAfter ["writeBoundary"] normalizeRemotes;
    };
  };
}
