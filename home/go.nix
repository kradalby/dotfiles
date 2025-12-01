{pkgs, ...}: {
  programs.go = {
    enable = true;
    env = {
      GOPATH = "go";
    };
    package = pkgs.go;
  };
}
