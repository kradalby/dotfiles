{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "disk-cleanup";

  # docker and nix-collect-garbage come from PATH: use what the host runs.
  runtimeInputs = with pkgs; [
    coreutils
    findutils
    (import ./tmp-cleanup.nix { inherit pkgs; })
  ];

  text = builtins.readFile ./disk-cleanup.sh;
}
