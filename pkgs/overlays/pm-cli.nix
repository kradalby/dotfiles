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
    hash = "sha256-fYrhOOdXQqOHvidxMYE56/bwse9nFrDrOvf/HoDEwR4=";
  };
  vendorHash = "sha256-aLadJA+AO86vN/bzk9KuglBfV8U6dMtenviOLQX8lUg=";
  env = {
    CGO_ENABLED = 0;
  };
  subPackages = [ "cmd/pm-cli" ];
}
