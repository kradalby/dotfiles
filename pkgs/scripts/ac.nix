{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "ac";

  runtimeInputs =
    (with pkgs; [
      rex-cli
      git
      jq
      websocat
      coreutils
      gnused
      # Agents launch under `direnv exec`; the standing-session unit has no
      # profile PATH to find it on.
      direnv
      # `hostname` is not part of coreutils; the remote-control name needs it and
      # the boot-time permagent unit has no interactive profile to fall back on.
      hostname
    ])
    # Role sessions report the gate's verdict in their opening briefing, and ac
    # runs outside the dotfiles devShell, so it carries its own copy.
    ++ [ (import ./git-ready.nix { inherit pkgs; }) ];

  text = builtins.readFile ./ac.sh;
}
