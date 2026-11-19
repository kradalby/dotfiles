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
      ../../home/atuin.nix
    ];
    my.atuin.enable = true; # personal account (shared with dev.ldn)

    my.packages.ai.codex = true;
    my.cooklang.recipes = "/Users/kradalby/cooklang";

    home.packages = with pkgs; [
      pm-cli
    ];
  };
}
