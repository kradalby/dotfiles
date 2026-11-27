{
  src,
  version,
  buildGoModule,
}:
buildGoModule rec {
  pname = "squibble";
  inherit src version;

  vendorHash = "sha256-clJBCC4vgPn03KTTMERRcFosD2zNSYOaM3p6Eou/0VI=";
  env = {
    CGO_ENABLED = 0;
  };
  subPackages = [ "cmd/squibble" ];
}
