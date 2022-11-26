{pkgs, ...}: {
  services.nix-daemon = {
    enable = true;
  };

  nix = {
    package = pkgs.nixUnstable;
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
      allowBroken = true; # TODO: Remove
    };
  };
}
