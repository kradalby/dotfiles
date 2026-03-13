{
  buildGoModule,
  fetchFromGitHub,
  libffi,
}: let
  versions = import ../../metadata/versions.nix;
in
  buildGoModule rec {
    name = "boo";
    # NOTE: manual update required
    # https://github.com/seruman/boo/commits/main/
    version = versions.pkgs.overlays.boo;

    src = fetchFromGitHub {
      owner = "seruman";
      repo = "boo";
      rev = "${version}";
      hash = "sha256-Hyb0tFD/yvZ0/jPNiZsi28ryHhcufdBZCE8JIPZnLnM=";
    };
    vendorHash = "sha256-sfiu7FrcbyUcYhfyXa4RU73Zg0S0Gi2KNaQqmwygJzo=";

    buildInputs = [
      libffi
    ];

    # boo uses darwinkit which requires CGo for Objective-C bridging.
    env = {
      CGO_ENABLED = 1;
    };

    meta = {
      description = "CLI tool to control Ghostty terminal via AppleScript";
      homepage = "https://github.com/seruman/boo";
    };
  }
