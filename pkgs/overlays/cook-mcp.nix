{
  lib,
  fetchFromGitHub,
  rustPlatform,
}:
let
  versions = import ../../metadata/versions.nix;
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "cook-mcp";
  # NOTE: manual update required
  # https://github.com/cook-md/cook-mcp/releases
  version = versions.pkgs.overlays.cookMcp;

  # Plain upstream source: consumers link skills/ from src.
  src = fetchFromGitHub {
    owner = "cook-md";
    repo = "cook-mcp";
    rev = "v${finalAttrs.version}";
    hash = "sha256-nNPx5u1sgrwe3C/6crTGSRUGi9LnnlFY+NfCwXaY47k=";
  };

  cargoHash = "sha256-pnh2P0VmvZc45xjVuQz5mJLy/SL/0PRFmkqCy903zFg=";

  meta = {
    changelog = "https://github.com/cook-md/cook-mcp/releases/tag/v${finalAttrs.version}";
    description = "MCP server for Cooklang recipes and cook.md";
    homepage = "https://cook.md/help/mcp";
    license = lib.licenses.mit;
    mainProgram = "cook-mcp";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
