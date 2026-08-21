{ buildGoModule }:
buildGoModule {
  pname = "authkey";
  version = "unstable";

  src = ./.;
  vendorHash = "sha256-iDBYS7LR3eYKD3N5DQ+FWZN80I4Fik0sk4F7y09YEzo=";
  env.CGO_ENABLED = 0;
}
