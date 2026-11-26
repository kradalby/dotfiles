{
  lib,
  buildGoModule,
}:
buildGoModule {
  pname = "github-star-feed";
  version = "0.1.0";

  src = ./.;

  vendorHash = "sha256-7jag6wpHT7cg/zMbVaHZ6qEzWCh89N8WmsMWbP+zbS8=";

  env.CGO_ENABLED = 0;

  meta = {
    description = "GitHub private feed filtered to star and follow events";
    license = lib.licenses.mit;
    mainProgram = "github-star-feed";
  };
}
