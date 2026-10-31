{
  lib,
  buildGoModule,
}:
buildGoModule {
  pname = "energyd";
  version = "0.1.0";

  src = ./.;

  vendorHash = "sha256-0M4B6dSrsEsTW5es8/NORnKlUu8Npw9WSUTU36gcuaQ=";

  env.CGO_ENABLED = 0;

  meta = {
    description = "Ledger of what energy costs this home, from NextEnergy, day-ahead prices and the P1 meter";
    license = lib.licenses.mit;
    mainProgram = "energyd";
  };
}
