{ buildGoModule }:
buildGoModule {
  pname = "authkey";
  version = "unstable";

  src = ./.;
  vendorHash = "sha256-6EVDWCjRa1pndFNoz39GZTdjpEL6N9/k4/wYVHMI+Qg=";
  env.CGO_ENABLED = 0;
}
