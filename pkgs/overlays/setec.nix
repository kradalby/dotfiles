{
  buildGoModule,
  fetchFromGitHub,
}:
let
  versions = import ../../metadata/versions.nix;
in
buildGoModule rec {
  name = "setec";
  # NOTE: manual update required
  # https://github.com/tailscale/setec/commits/main/
  version = versions.pkgs.overlays.setec;

  src = fetchFromGitHub {
    owner = "tailscale";
    repo = "setec";
    rev = "${version}";
    sha256 = "sha256-8V8NwtZE+Ud5jW+4YO6hMruElaBQmvjG/tp+UTuVQx8=";
  };
  vendorHash = "sha256-VQ2fY3QyepDt0ymgFgEKB50zXezgu6Il6SL5lBJQjGA=";
  env = {
    CGO_ENABLED = 0;
  };
  subPackages = [ "cmd/setec" ];
}
