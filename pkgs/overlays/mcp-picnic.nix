{
  src,
  version,
  lib,
  buildNpmPackage,
  importNpmLock,
}:
buildNpmPackage (finalAttrs: {
  pname = "mcp-picnic";
  inherit src version;

  # Deps from the pinned package-lock.json: a version bump needs no hash.
  npmDeps = importNpmLock { npmRoot = src; };
  npmConfigHook = importNpmLock.npmConfigHook;

  # Upstream reads HTTP_HOST but never passes it to listen(), so the server
  # binds every interface — on home.ldn that is the trusted LAN, unauthenticated.
  postPatch = ''
    substituteInPlace src/transports/streamable-http.ts \
      --replace-fail 'this.app.listen(this.port, () =>' 'this.app.listen(this.port, this.host, () =>'
  '';

  meta = {
    description = "MCP server for the Picnic grocery delivery service";
    homepage = "https://github.com/ivo-toby/mcp-picnic";
    license = lib.licenses.mit;
    mainProgram = "mcp-server-template";
  };
})
