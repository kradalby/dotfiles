{pkgs, ...}: {
  nix = {
    settings = {
      connect-timeout = 5;
      fallback = true;
      accept-flake-config = true;
      substituters = [
        "https://nix-community.cachix.org?priority=41"
        "https://numtide.cachix.org?priority=42"
      ];
      trusted-substituters = [
        "http://nix-cache.dalby.ts.net"
      ];
      trusted-public-keys = [
        "nix-cache:XtaO+MWYNBtMJn3eIUucmx0dkeLzMI7+n984nZYFt4I="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
      ];
    };

    package = pkgs.nixVersions.latest;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';

    settings = {
      # todo
      sandbox = false;
    };

    gc = {
      automatic = true;
      options = "--delete-older-than 5d";
    };
  };

  nixpkgs = {
    config = {
      allowUnfree = true;
    };
  };
}
