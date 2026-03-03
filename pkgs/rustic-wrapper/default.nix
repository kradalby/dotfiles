{
  lib,
  buildGoModule,
}:
buildGoModule {
  pname = "rustic-wrapper";
  version = "0.1.0";

  src = ./.;

  vendorHash = null;

  env.CGO_ENABLED = 0;

  meta = {
    description = "Compiled Mach-O wrapper for RusticBackup.app FDA grant on macOS";
    license = lib.licenses.mit;
    mainProgram = "rustic-wrapper";
  };
}
