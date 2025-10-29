{buildGoModule}:
buildGoModule {
  name = "ts-preauthkey";

  src = ./.;
  vendorHash = "sha256-jKolWBbb490Gr0pBn5YAPMQAygy7TcOgtj9XpLB0pVE=";
  env.CGO_ENABLED = 0;
  doCheck = false;
}
