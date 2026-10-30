{ buildGoModule }:
buildGoModule {
  pname = "authkey";
  version = "unstable";

  src = ./.;
  vendorHash = "sha256-T/LjUPZHbKipPKvFGo/9/1MqPNyrrDQRUUvdpC+xTi8=";
  env.CGO_ENABLED = 0;
}
