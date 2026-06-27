{pkgs, ...}:
pkgs.writeShellApplication {
  name = "tailscale-switch-toggle";

  runtimeInputs = with pkgs; [jq];

  text = builtins.readFile ./tailscale-switch-toggle.sh;
}
