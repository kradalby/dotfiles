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
      hash = "sha256-Iyx5KuCqePmn2gbSEcoiTWiFQu4iT5rWvV0jnMbR9Y4=";
    };
    vendorHash = "sha256-sxzCiyFzZJh8KXpTd+cxM+Uh2GYhSMpx3d4hkTotESU=";
  }
)
