{pkgs, ...}:
pkgs.writeShellApplication {
  name = "ghostty-new-mosh-tab";

  runtimeInputs = with pkgs; [ghostty-tab];

  text = builtins.readFile ./ghostty-new-mosh-tab.sh;
}
