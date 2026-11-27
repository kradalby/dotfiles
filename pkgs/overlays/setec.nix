{
  src,
  version,
  buildGoModule,
}:
buildGoModule rec {
  name = "setec";
  inherit src version;

  vendorHash = "sha256-OWW4+k/+tpAn5N4w0/5peEpGwbIHVyXp2m857JVKuFs=";
  env = {
    CGO_ENABLED = 0;
  };
  subPackages = [ "cmd/setec" ];
}
