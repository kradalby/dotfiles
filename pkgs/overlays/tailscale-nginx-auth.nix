{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  pname = "tailscale-nginx-auth";
  version = "19b558657308a0cd6d8e2eac272737552fb04725";

  src = fetchFromGitHub {
    owner = "tailscale";
    repo = "tailscale";
    rev = "${version}";
    sha256 = "sha256-3OeO2mL3jiynmZjUbo0znRf/0M/pRR4T/kpDtC8uTWU=";
  };

  subPackages = ["cmd/nginx-auth/nginx-auth.go"];

  vendorSha256 = "sha256-VKwuEdMRBa8u1GXnp1yDRGjjG0uTGLdqOF9jgaZ6cwo=";

  meta = with lib; {
    homepage = "https://github.com/tailscale/tailscale/tree/main/cmd/nginx-auth";
    description = "tailscale nginx auth";
    longDescription = ''
      https://tailscale.com/blog/tailscale-auth-nginx/
    '';
    license = licenses.bsd3;
    maintainers = with maintainers; [kradalby];
  };
}
