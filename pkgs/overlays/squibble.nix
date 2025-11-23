{
  buildGoModule,
  fetchFromGitHub,
}: let
  versions = import ../../metadata/versions.nix;
in
buildGoModule rec {
  name = "squibble";
  # NOTE: manual update required
  # https://github.com/tailscale/squibble/commits/main/
  version = versions.pkgs.overlays.squibble;

  src = fetchFromGitHub {
    owner = "tailscale";
    repo = "squibble";
    rev = "${version}";
    sha256 = "sha256-6zLQBVbQHZmUgFWdoj8Jz7dNol60RDXXUFd+bVeNelc=";
  };
  vendorHash = "sha256-b9lm7SdRJb+jElnzOugx/PpL/x8/UX/87oPgPk2PRiY=";
  env = {
    CGO_ENABLED = 0;
  };
  subPackages = ["cmd/squibble"];
}
