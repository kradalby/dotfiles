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
  version = "v0.6.0";

  src = fetchFromGitHub {
    owner = "cooklang";
    repo = pname;
    rev = version;
    sha256 = "sha256-d+jPaPYvtFaiWaNyyOpazmhR3LSe5DfKjdM4dkdaQHw=";
  };

  cargoSha256 = "sha256-xVXQJsmJ4Exnqqe4Z43quxlZBWHAQt6qMrhceOAvUiw=";

  meta = with lib; {
    description = "Command line program which provides a suite of tools to create shopping lists and maintain recipes.";
    homepage = "https://github.com/cooklang/cookcli";
    license = licenses.unlicense;
    maintainers = [maintainers.kradalby];
  };
}
