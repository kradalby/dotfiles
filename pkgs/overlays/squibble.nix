{
  buildGoModule,
  fetchFromGitHub,
}:
let
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
    hash = "sha256-jUD1aN4kFhM39HAkdKJPUZusOkZtYNWJfU9c43zmzv0=";
  };
  vendorHash = "sha256-clJBCC4vgPn03KTTMERRcFosD2zNSYOaM3p6Eou/0VI=";
  env = {
    CGO_ENABLED = 0;
  };
  subPackages = [ "cmd/squibble" ];
}
