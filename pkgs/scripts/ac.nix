{pkgs, ...}:
pkgs.writeShellApplication {
  name = "ac";

  runtimeInputs = with pkgs; [
    boo
    jq
    git
    coreutils
    gnused
  ];

  text = builtins.readFile ./ac.sh;
}
