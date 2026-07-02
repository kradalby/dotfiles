{pkgs, ...}:
pkgs.writeShellApplication {
  name = "rmkh";

  runtimeInputs = with pkgs; [
    openssh
    gnused
  ];

  text = builtins.readFile ./rmkh.sh;
}
