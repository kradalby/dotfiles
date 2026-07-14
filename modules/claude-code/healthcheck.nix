{
  pkgs,
  lib,
  ...
}:
pkgs.writeShellApplication {
  name = "claude-code-health";

  # launchctl (Darwin) comes from /usr/bin via the unit's PATH, not nixpkgs.
  runtimeInputs =
    (with pkgs; [
      coreutils
      gnugrep
      findutils
    ])
    ++ lib.optional pkgs.stdenv.isLinux pkgs.systemd;

  text = builtins.readFile ./healthcheck.sh;
}
