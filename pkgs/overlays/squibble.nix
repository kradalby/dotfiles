{
  buildGoModule,
  fetchFromGitHub,
}: let
  versions = import ../../metadata/versions.nix;
in
  buildGoModule rec {
    pname = "squibble";
    # NOTE: manual update required
    # https://github.com/tailscale/squibble/commits/main/
    version = versions.pkgs.overlays.squibble;

    src = fetchFromGitHub {
      owner = "tailscale";
      repo = "squibble";
      rev = "${version}";
      hash = "sha256-KGtHqsy+V3/sBSk7aUZJIyDPG8hrMPIBmKnQb7ZC2To=";
    };
    vendorHash = "sha256-b9lm7SdRJb+jElnzOugx/PpL/x8/UX/87oPgPk2PRiY=";
    env = {
      CGO_ENABLED = 0;
    };
    subPackages = ["cmd/squibble"];
  }
