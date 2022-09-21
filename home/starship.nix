{pkgs, ...}: {
  programs.starship = {
    enable = true;
    package = pkgs.starship;
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
