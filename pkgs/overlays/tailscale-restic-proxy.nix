{
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  name = "tailscale-restic-proxy";
  # NOTE: manual update required
  # https://github.com/JonaEnz/tailscale-restic-proxy/commits/main/
  version = "7568fa9106768a017465ac6a00b5e20865bd4b4f";

  src = fetchFromGitHub {
    owner = "JonaEnz";
    repo = "tailscale-restic-proxy";
    rev = "${version}";
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };
  vendorHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  CGO_ENABLED = 0;
  subPackages = ["cmd/ts-restic-proxy"];
  doCheck = false;
}
