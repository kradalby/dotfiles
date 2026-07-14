{
  config,
  pkgs,
  lib,
  claudeCodeLib,
  ...
}:
let
  inherit (claudeCodeLib) resolvePath mkArgs enabled;

  darwinPath = "${config.home.profileDirectory}/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin";

  healthcheck = import ./healthcheck.nix { inherit pkgs lib; };

  mkLaunchdAgent = name: ic: {
    enable = true;
    config = {
      ProgramArguments = mkArgs name ic;
      WorkingDirectory = resolvePath ic.path;
      RunAtLoad = true;
      # Always respawn: the app exits 0 on graceful shutdown ("Environment
      # preserved…"), which SuccessfulExit=false would leave down until the
      # next activation. The watchdog handles the not-loaded case.
      KeepAlive = true;
      ProcessType = "Background";
      EnvironmentVariables = {
        PATH = darwinPath;
        HOME = config.home.homeDirectory;
      };
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/claude-code-${name}.log";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/claude-code-${name}-error.log";
    };
  };
in
{
  config = lib.mkIf (pkgs.stdenv.isDarwin && enabled != { }) {
    launchd.agents =
      (lib.mapAttrs' (n: ic: lib.nameValuePair "claude-code-${n}" (mkLaunchdAgent n ic)) enabled)
      // {
        # KeepAlive only restarts on exit. This catches the alive-but-stuck case
        # (bridge disconnect / lost login). launchctl comes from /usr/bin via
        # darwinPath; the rest is bundled in the package's runtimeInputs.
        claude-code-health = {
          enable = true;
          config = {
            ProgramArguments = [ "${healthcheck}/bin/claude-code-health" ] ++ lib.attrNames enabled;
            StartInterval = 120;
            ProcessType = "Background";
            EnvironmentVariables = {
              PATH = darwinPath;
              HOME = config.home.homeDirectory;
            };
            StandardOutPath = "${config.home.homeDirectory}/Library/Logs/claude-code-health.log";
            StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/claude-code-health-error.log";
          };
        };
      };
  };
}
