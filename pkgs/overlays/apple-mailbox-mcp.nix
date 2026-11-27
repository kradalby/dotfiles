{
  lib,
  python3Packages,
  fetchFromGitHub,
}:
let
  versions = import ../../metadata/versions.nix;
in
python3Packages.buildPythonApplication (finalAttrs: {
  pname = "apple-mailbox-mcp";
  version = versions.pkgs.overlays.appleMailboxMcp;
  pyproject = true;

  src = fetchFromGitHub {
    owner = "parasxos";
    repo = "apple-mail-mcp";
    tag = "v${finalAttrs.version}";
    hash = "sha256-mlsWuPC9Fo6pd3+YyzFWkBwHA7ZB4jOPauAfFvxjZh8=";
  };

  build-system = [ python3Packages.setuptools ];
  dependencies = with python3Packages; [
    certifi
    mcp
    pydantic
  ];

  # The suite drives a live Mail.app store.
  doCheck = false;
  pythonImportsCheck = [ "email_mcp" ];

  meta = {
    description = "Local MCP server for Apple Mail: search, read, triage";
    homepage = "https://github.com/parasxos/apple-mail-mcp";
    license = lib.licenses.mit;
    mainProgram = "apple-mailbox-mcp";
    platforms = lib.platforms.darwin;
  };
})
