{
  src,
  version,
  gotools,
}:
# x/tools must keep up with the Go release: nixpkgs' 0.44 predates the fleet's
# Go, and its go/packages loads no types there, breaking stringer and bundle.
gotools.overrideAttrs (
  _: _: {
    inherit src version;

    vendorHash = "sha256-sxzCiyFzZJh8KXpTd+cxM+Uh2GYhSMpx3d4hkTotESU=";
  }
)
