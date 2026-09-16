{
  buildGoModule,
  fetchFromGitHub,
}:
let
  versions = import ../../metadata/versions.nix;
in
buildGoModule rec {
  pname = "pm-cli";
  # https://github.com/bscott/pm-cli/releases
  version = versions.pkgs.overlays.pmCli;

  src = fetchFromGitHub {
    owner = "bscott";
    repo = "pm-cli";
    tag = "v${version}";
    hash = "sha256-Fy/Gpcl7tzVr52toDI6xTxm9K7fSl5i4zrncFf0tzZQ=";
  };
  vendorHash = "sha256-aLadJA+AO86vN/bzk9KuglBfV8U6dMtenviOLQX8lUg=";
  env = {
    CGO_ENABLED = 0;
  };
  subPackages = [ "cmd/pm-cli" ];
}
