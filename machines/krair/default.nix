# Personal Mac configuration
{ pkgs, ... }: {
  imports = [
    ../../common/darwin/kradalby-base.nix
    ./rustic.nix
    ./claude-code.nix
  ];

  homebrew = {
    casks = [
      "proton-mail-bridge"
    ];
  };

  home-manager.users.kradalby = {
    imports = [
      ../../home/herdr.nix
      ../../home/atuin.nix
    ];
    my.atuin.enable = true; # personal account (shared with dev.ldn)

    my.packages.ai.codex = true;
    # Default is claude+opencode; codex needs its own state hook or herdr
    # cannot tell idle from working in a codex pane.
    my.herdr.integrations = [
      "claude"
      "codex"
      "opencode"
    ];

    home.packages = with pkgs; [
      pm-cli
    ];
  };
}
