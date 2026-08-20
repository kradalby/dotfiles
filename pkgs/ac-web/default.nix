{ buildGoModule }:
buildGoModule {
  pname = "ac-web";
  version = "0.1.0";

  src = ./.;
  vendorHash = "sha256-j+Lhx7tdV7l94E6qztZQhFUX8FImq1C4nsaD6IBWcgg=";

  env.CGO_ENABLED = 0;

  meta = {
    description = "Auth-less Tailscale web UI to spawn `ac` coding-agent sessions from a phone";
    mainProgram = "ac-web";
  };
}
