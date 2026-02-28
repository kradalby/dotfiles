{pkgs, ...}:
pkgs.writeShellApplication {
  name = "ac";

  runtimeInputs = with pkgs; [
    tmux
    coreutils
    findutils
    gnused
  ];

  text = builtins.readFile ./ac.sh;
}
