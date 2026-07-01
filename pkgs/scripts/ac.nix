{pkgs, ...}:
pkgs.writeShellApplication {
  name = "ac";

  runtimeInputs = with pkgs; [
    tmux
    git
    jq
    coreutils
    findutils
    gnused
  ];

  text = builtins.readFile ./ac.sh;
}
