{ buildGoModule }:
buildGoModule {
  pname = "authkey";
  version = "unstable";

  src = ./.;
  vendorHash = "sha256-RKmc35/Rijtz8ZgPlVKoqSUSt7uqH784fuY0Ic2qnVA=";
  env.CGO_ENABLED = 0;
}
