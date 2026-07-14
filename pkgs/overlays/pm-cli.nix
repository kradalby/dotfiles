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
    hash = "sha256-eW8we4TCbGZjcQavXb0H7/4nSXwPw2M9LMJpoUWy03s=";
  };
  vendorHash = "sha256-E+2f1xF/t4c0Dl3kWRKn5F8CuEy8S9vawM/0VtX3m8Y=";
  env = {
    CGO_ENABLED = 0;
  };
  subPackages = [ "cmd/pm-cli" ];
}
