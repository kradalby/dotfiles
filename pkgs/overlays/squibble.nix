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
      hash = "sha256-4bTpCbwGZ5prixuglkMdGTb82Df07reTX5G++ZJ4y50=";
    };
    vendorHash = "sha256-vXWbETcpXLLB4aIOO5F6cwp1GGfE5NeQKJ22iNmtUDg=";
    env = {
      CGO_ENABLED = 0;
    };
    subPackages = ["cmd/squibble"];
  }
