{pkgs, ...}:{
  fonts = {
    fontDir.enable = true;
    fonts = [pkgs.jetbrains-mono pkgs.nerdfonts];
  };
}
