{
  config,
  pkgs,
  lib,
  claudeCodeLib,
  ...
}: let
  inherit (claudeCodeLib) resolvePath mkArgs enabled;

  darwinPath = "${config.home.profileDirectory}/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin";

  mkLaunchdAgent = name: ic: {
    enable = true;
    config = {
      ProgramArguments = mkArgs name ic;
      WorkingDirectory = resolvePath ic.path;
      RunAtLoad = true;
      KeepAlive = {SuccessfulExit = false;};
      ProcessType = "Background";
      EnvironmentVariables = {
        PATH = darwinPath;
        HOME = config.home.homeDirectory;
      };
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/claude-code-${name}.log";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/claude-code-${name}-error.log";
    };
  };
in {
  config = lib.mkIf (pkgs.stdenv.isDarwin && enabled != {}) {
    launchd.agents =
      lib.mapAttrs' (n: ic: lib.nameValuePair "claude-code-${n}" (mkLaunchdAgent n ic)) enabled;
  };
}
