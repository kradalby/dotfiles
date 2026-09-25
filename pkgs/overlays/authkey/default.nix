{ buildGoModule }:
buildGoModule {
  pname = "authkey";
  version = "unstable";

  src = ./.;
  vendorHash = "sha256-BQFVfd9uI3ehB2NdXdEqAbr4yjiPxUvKUTmrVQEDA2Y=";
  env.CGO_ENABLED = 0;
}
