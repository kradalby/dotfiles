{
  lib,
  stdenv,
  fetchFromGitHub,
  rustPlatform,
}:
rustPlatform.buildRustPackage rec {
  pname = "eb";
  version = "v0.5.0";

  src = fetchFromGitHub {
    owner = "rye";
    repo = pname;
    rev = version;
    sha256 = "sha256-kHN9W4oKlSIiJlbu3Jd9HAIQjk1jTk/2sHr1eLlydD8=";
  };

  cargoSha256 = "sha256-9ZbL+FlpRKUcMcpFigR3JwAbAs5w55iapJwpuqVyI14=";

  meta = with lib; {
    description = "♻️ Run commands with exponential backoff 📈";
    homepage = "https://github.com/rye/eb";
    license = licenses.unlicense;
    maintainers = [maintainers.kradalby];
  };
}
