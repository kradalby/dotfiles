{ buildGoModule }:
buildGoModule {
  pname = "authkey";
  version = "unstable";

  src = ./.;
  vendorHash = "sha256-/XFr7INmctu34BIIvXMkWJZt1YWsrG3Q7olhQj95GL4=";
  env.CGO_ENABLED = 0;
}
