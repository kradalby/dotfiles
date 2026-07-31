{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "exportphotos";

  runtimeInputs = with pkgs; [ jq ];

  text = builtins.replaceStrings [ "@config@" ] [ "${./osxphotos.toml}" ] (
    builtins.readFile ./exportphotos.sh
  );
}
