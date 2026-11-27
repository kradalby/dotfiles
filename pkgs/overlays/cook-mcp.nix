{
  src,
  version,
  lib,
  rustPlatform,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "cook-mcp";
  inherit src version;

  # Plain upstream source: consumers link skills/ from src.

  # Deps from the pinned Cargo.lock: a version bump needs no hash.
  cargoLock.lockFile = "${src}/Cargo.lock";

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
