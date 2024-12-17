{pkgs, ...}: {
  services.nix-daemon = {
    enable = true;
  };

  nix = {
    settings = {
      substituters = [
        "https://nix-community.cachix.org?priority=41"
        "https://numtide.cachix.org?priority=42"
        "http://attic/system?priority=43"
      ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
        "system:40arGOg81ZACFJQAksoEplo8PfgxDd6aEQpNbuHXcCg="
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
