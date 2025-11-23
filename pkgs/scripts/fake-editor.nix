{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "fake-editor";
  text = ''
    cat >"$1"
    exit 0
  '';
}
