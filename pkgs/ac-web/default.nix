{buildGoModule}:
buildGoModule {
  pname = "ac-web";
  version = "0.1.0";

  src = ./.;
  vendorHash = null; # stdlib only, no external deps

  env.CGO_ENABLED = 0;

  meta = {
    description = "Auth-less Tailscale web UI to spawn `ac` coding-agent sessions from a phone";
    mainProgram = "ac-web";
  };
}
