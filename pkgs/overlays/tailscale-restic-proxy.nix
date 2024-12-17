{
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  name = "tailscale-restic-proxy";
  # NOTE: manual update required
  # https://github.com/JonaEnz/tailscale-restic-proxy/commits/main/
  version = "082b25b1ec3d1b27d5d62c04dc242680a47dcd21";

  src = fetchFromGitHub {
    owner = "JonaEnz";
    repo = "tailscale-restic-proxy";
    rev = "${version}";
    sha256 = "sha256-Erh7xdHNq1W9eFCTwGb59+95JN3TxqIzU7iksZjJ7aM=";
  };
  vendorHash = "sha256-gMmCD9agebtca9fDn39tt2AQX5bD2cYz7DS01g6uuOs=";
  CGO_ENABLED = 0;
  subPackages = ["cmd/ts-restic-proxy"];
  doCheck = false;
}
