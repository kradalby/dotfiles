{pkgs, ...}: {
  programs.go = {
    enable = true;
    goPath = "go";
    package = pkgs.master.go_1_23;
  };
}
