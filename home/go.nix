{pkgs, ...}: {
  programs.go = {
    enable = true;
    env = {
      GOPATH = "go";
    };
    package = pkgs.go;
  };

  home.sessionVariables = {
    GOPATH = "$HOME/go";
  };
}
