{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "nix-dev-env";

  # The script manages its own control flow and relies on non-zero exits
  # being non-fatal (e.g. `[ flake.nix -nt "$cf" ] && stale=1`). errexit
  # would kill it, so disable the default strict options.
  bashOptions = [ ];

  runtimeInputs = with pkgs; [
    jq
    direnv
    nix
    coreutils # sha256sum, cut, mkdir, cat
    gnugrep
    gnused
  ];

  text = builtins.readFile ./nix-dev-env.sh;
}
