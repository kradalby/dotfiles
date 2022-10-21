{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  pname = "tailscale-nginx-auth";
  version = "cfbbcf6d071dd13addbc1b38ef993a08d557ba22";

  src = fetchFromGitHub {
    owner = "tailscale";
    repo = "tailscale";
    rev = "${version}";
    sha256 = "sha256-2yA5g4YeCvT3u/Wm/J7TciMRIeWoH/4/hKyTjlucvuQ=";
  };

  subPackages = ["cmd/nginx-auth/nginx-auth.go"];

  vendorSha256 = "sha256-ipBY8F3pdWzGKTk2F7K1vz8rWxCffABJ5q9e9WLxFJ0=";

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
