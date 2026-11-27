{
  src,
  version,
  lib,
  stdenv,
  rustPlatform,
}:
rustPlatform.buildRustPackage rec {
  # https://github.com/rye/eb
  pname = "eb";
  inherit src version;

  # Deps from the pinned Cargo.lock: a version bump needs no hash.
  cargoLock.lockFile = "${src}/Cargo.lock";

  meta = with lib; {
    description = "♻️ Run commands with exponential backoff 📈";
    homepage = "https://github.com/rye/eb";
    license = licenses.unlicense;
    maintainers = [ maintainers.kradalby ];
  };
}
