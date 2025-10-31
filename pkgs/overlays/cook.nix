{
  lib,
  stdenv,
  fetchFromGitHub,
  rustPlatform,
}:
rustPlatform.buildRustPackage rec {
  pname = "cookcli";
  # NOTE: manual update required
  # https://github.com/cooklang/cookcli/releases
  version = "v0.18.2";

  src = fetchFromGitHub {
    owner = "cooklang";
    repo = pname;
    rev = version;
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  cargoHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

  meta = with lib; {
    description = "Command line program which provides a suite of tools to create shopping lists and maintain recipes.";
    homepage = "https://github.com/cooklang/cookcli";
    license = licenses.unlicense;
    maintainers = [maintainers.kradalby];
  };
}
