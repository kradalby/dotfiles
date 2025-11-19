{
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  name = "setec";
  # NOTE: manual update required
  # https://github.com/tailscale/setec/commits/main/
  version = "bc7a01a47c9cda0acbff2a49eda50708f59a47b1";

  src = fetchFromGitHub {
    owner = "tailscale";
    repo = "setec";
    rev = "${version}";
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };
  vendorHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  env = {
    CGO_ENABLED = 0;
  };
  subPackages = ["cmd/setec"];
}
