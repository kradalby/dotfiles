{ pkgs, ... }:
{
  programs.kitty = {
    enable = true;
    darwinLaunchOptions = [
      "--single-instance"
    ];

    font = {
      package = pkgs.jetbrains-mono;
      name = "JetBrainsMono Nerd Font";
      size = 8;
    };

    # https://nix-community.github.io/home-manager/options.html#opt-programs.kitty.keybindings
  };
}
