{ pkgs, ... }:
{
  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      add_newline = true;

      time = {
        disabled = false;
      };

      kubernetes = {
        style = "purple";
        symbol = "⛵ ";
        disabled = false;
      };
    };
  };
}
