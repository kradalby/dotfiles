{ buildGoModule }:
buildGoModule {
  pname = "authkey";
  version = "unstable";

  src = ./.;
  vendorHash = "sha256-CFuY4CnbSMgGJyAnbHGyJbkiora6N1FoL5pbWNDWYu0=";
  env.CGO_ENABLED = 0;
}
