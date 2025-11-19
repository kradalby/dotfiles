{
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  name = "squibble";
  # NOTE: manual update required
  # https://github.com/tailscale/squibble/commits/main/
  version = "4d5df9caa9931e8341ce65d7467681c0b225d22b";

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
