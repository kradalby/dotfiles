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
    sha256 = "";
  };

  cargoSha256 = "";

  meta = with lib; {
    description = "♻️ Run commands with exponential backoff 📈";
    homepage = "https://github.com/rye/eb";
    license = licenses.unlicense;
    maintainers = [maintainers.kradalby];
  };
}
