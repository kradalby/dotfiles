{pkgs, ...}:
pkgs.writeShellApplication {
  name = "ac";

  runtimeInputs = with pkgs; [
    tmux
    git
    coreutils
    findutils
    gnused
  ];

  text = builtins.readFile ./ac.sh;
}
