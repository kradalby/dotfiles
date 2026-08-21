{ buildGoModule }:
buildGoModule {
  pname = "ac-web";
  version = "0.1.0";

  src = ./.;
  vendorHash = "sha256-5cKs+6VEhARtftAhqwmnjysLNo9UKhzpT8R1ZvUgz0M=";

  env.CGO_ENABLED = 0;

  meta = {
    description = "Auth-less Tailscale web UI to spawn `ac` coding-agent sessions from a phone";
    mainProgram = "ac-web";
  };
}
