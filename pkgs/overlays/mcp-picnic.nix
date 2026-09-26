{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:
let
  versions = import ../../metadata/versions.nix;
in
buildNpmPackage (finalAttrs: {
  pname = "mcp-picnic";
  version = versions.pkgs.overlays.mcpPicnic;

  src = fetchFromGitHub {
    owner = "ivo-toby";
    repo = "mcp-picnic";
    rev = "v${finalAttrs.version}";
    hash = "sha256-lfWvOhqL0p1QmD8dkPOfOXIh7ln4j1dZZPK7GIQuruE=";
  };

  npmDepsHash = "sha256-b+M+o7sPyWj+NDB3V9V9T11LypTbthdTJ0VKoDdfyGY=";

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
