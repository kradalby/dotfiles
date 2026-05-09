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

  mkUnit = name: ic: let
    instanceName =
      if ic.name == ""
      then name
      else ic.name;
    instancePrefix =
      if ic.prefix == ""
      then name
      else ic.prefix;
    workingDir = resolvePath ic.path;
    args =
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
      ++ [
        (
          if ic.sandbox
          then "--sandbox"
          else "--no-sandbox"
        )
      ];
  in {
    Unit = {
      Description = "claude remote-control: ${name}";
      After = ["network-online.target"];
      Wants = ["network-online.target"];
    };
    Service = {
      Type = "simple";
      WorkingDirectory = workingDir;
      ExecStart = lib.escapeShellArgs args;
      Restart = "on-failure";
      RestartSec = 15;
      KillSignal = "SIGTERM";
      TimeoutStopSec = 15;
      Environment = [
        "PATH=${config.home.profileDirectory}/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin"
        "HOME=${config.home.homeDirectory}"
      ];
    };
    Install.WantedBy = ["default.target"];
  };

  enabled = lib.filterAttrs (_: ic: ic.enable) cfg;
in {
  options.services.claude-code = lib.mkOption {
    default = {};
    description = "Multiple `claude remote-control` instances, one systemd user service per attribute.";
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

  config = lib.mkIf (enabled != {}) {
    systemd.user.services =
      lib.mapAttrs' (n: ic: lib.nameValuePair "claude-code-${n}" (mkUnit n ic)) enabled;
  };
}
