{
  gotools,
  fetchFromGitHub,
}:
let
  versions = import ../../metadata/versions.nix;
in
# x/tools must keep up with the Go release: nixpkgs' 0.44 predates the fleet's
# Go, and its go/packages loads no types there, breaking stringer and bundle.
gotools.overrideAttrs (
  finalAttrs: _: {
    # NOTE: manual update required
    # https://github.com/golang/tools/tags
    version = versions.pkgs.overlays.gotools;

    src = fetchFromGitHub {
      owner = "golang";
      repo = "tools";
      tag = "v${finalAttrs.version}";
      hash = "sha256-invRApL81q9uIUCbBUhWGyS+14OKK6HZYdONzhHGKP4=";
    };
    vendorHash = "sha256-+1/eKOwN4yUvLCgGRJbW6MTleIEodfcIoEHCBRHd2MQ=";
  }
)
