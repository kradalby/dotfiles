{
  src,
  version,
  buildGoModule,
}:
buildGoModule rec {
  pname = "pm-cli";
  inherit src version;

  vendorHash = "sha256-aLadJA+AO86vN/bzk9KuglBfV8U6dMtenviOLQX8lUg=";
  env = {
    CGO_ENABLED = 0;
  };
  subPackages = [ "cmd/pm-cli" ];
}
