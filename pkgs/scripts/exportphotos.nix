{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "exportphotos";

  runtimeInputs = with pkgs; [ jq ];

  text = builtins.readFile ./exportphotos.sh;
}
