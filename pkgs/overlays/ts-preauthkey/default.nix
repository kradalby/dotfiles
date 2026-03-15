{buildGoModule}:
buildGoModule {
  pname = "ts-preauthkey";
  version = "unstable";

  src = ./.;
  vendorHash = "sha256-XXh2RGt1stpfZv8bNqfgGLZVz38Bd+kMNfFZZovTqXg=";
  env.CGO_ENABLED = 0;
}
