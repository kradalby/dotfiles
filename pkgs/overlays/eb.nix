{
  lib,
  stdenv,
  fetchFromGitHub,
  rustPlatform,
}:
rustPlatform.buildRustPackage rec {
  # NOTE: manual update required
  # https://github.com/rye/eb
  pname = "eb";
  version = "v0.5.0";

  src = fetchFromGitHub {
    owner = "rye";
    repo = pname;
    rev = version;
    sha256 = "sha256-kHN9W4oKlSIiJlbu3Jd9HAIQjk1jTk/2sHr1eLlydD8=";
  };

  cargoHash = "sha256-ybbayOxV2zXPK4A/92HbOT3i+8dG3u6/9vqZLxNCEJ8=";

  meta = with lib; {
    description = "♻️ Run commands with exponential backoff 📈";
    homepage = "https://github.com/rye/eb";
    license = licenses.unlicense;
    maintainers = [maintainers.kradalby];
  };
}
