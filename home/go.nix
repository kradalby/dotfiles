{pkgs, ...}: {
  programs.go = {
    enable = true;
    goPath = "go";
    package = pkgs.go;
  };
}
