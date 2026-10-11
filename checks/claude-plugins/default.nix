{ pkgs }:
let
  manifests = map (plugin: "${plugin}/.claude-plugin/plugin.json") pkgs.claude-plugins;
in
pkgs.runCommand "claude-plugin-tests" { nativeBuildInputs = [ pkgs.jq ]; } ''
  jq -se 'length == 11 and (map(.name) | unique | length) == 11' \
    ${pkgs.lib.escapeShellArgs manifests}
  jq -e '.name == "gopls-lsp" and .lspServers.gopls.command == "gopls"
    and .lspServers.gopls.extensionToLanguage[".go"] == "go"' \
    ${builtins.head manifests}
  touch $out
''
