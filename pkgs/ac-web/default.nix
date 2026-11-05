{ buildGoModule }:
buildGoModule {
  pname = "ac-web";
  version = "0.1.0";

  src = ./.;
  vendorHash = "sha256-i5R7+H4+K9O7VpqRqkCd57aXcMMKahk86doWaY/fHlo=";

  env.CGO_ENABLED = 0;

  meta = {
    description = "Auth-less Tailscale web UI to spawn `ac` coding-agent sessions from a phone";
    mainProgram = "ac-web";
  };
}
