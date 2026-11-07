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

  # rmcp handles each notification and request in its own task, so a request
  # right after roots/list_changed can still see the old root (flaky on darwin).
  checkFlags = [ "--skip=client_roots_choose_the_recipe_folder_when_started_in_root_dir" ];

  meta = {
    changelog = "https://github.com/cook-md/cook-mcp/releases/tag/v${finalAttrs.version}";
    description = "MCP server for Cooklang recipes and cook.md";
    homepage = "https://cook.md/help/mcp";
    license = lib.licenses.mit;
    mainProgram = "cook-mcp";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
