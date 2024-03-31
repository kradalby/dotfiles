{
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  name = "squibble";
  # NOTE: manual update required
  # https://github.com/tailscale/squibble/commits/main/
  version = "06b7fb49994db7c5c56b9b500dddfb05f4d11a01";

  src = fetchFromGitHub {
    owner = "tailscale";
    repo = "squibble";
    rev = "${version}";
    sha256 = "sha256-/H4bitzrru9rbNyzZbmzBuyWb8KaLFQ78TI5hd3uyUs=";
  };
  vendorHash = "sha256-gA9ODAGuvR05CW+efhFuTFVXnMHVXIlfRq2FqzxZqCY=";
  CGO_ENABLED = 0;
  subPackages = ["cmd/squibble"];
  doCheck = false;
}
