{ inputs, pkgs }:
let
  official = inputs.claude-plugins-official;
  marketplace = builtins.fromJSON (builtins.readFile "${official}/.claude-plugin/marketplace.json");
  gopls = pkgs.lib.findFirst (
    plugin: plugin.name == "gopls-lsp"
  ) (throw "gopls-lsp is missing from the official Claude marketplace") marketplace.plugins;
  goplsManifest = (pkgs.formats.json { }).generate "gopls-plugin.json" {
    inherit (gopls)
      name
      version
      description
      author
      lspServers
      ;
  };
  # The marketplace carries gopls's manifest instead of its plugin directory.
  goplsPlugin = pkgs.runCommand "claude-gopls-plugin" { } ''
    mkdir -p $out/.claude-plugin
    ln -s ${goplsManifest} $out/.claude-plugin/plugin.json
  '';
in
[
  goplsPlugin
  "${inputs.claude-plugins-official}/plugins/code-simplifier"
  "${inputs.claude-plugins-official}/plugins/frontend-design"
  "${inputs.claude-plugins-official}/plugins/code-review"
  "${inputs.claude-plugins-official}/external_plugins/github"
  "${inputs.claude-plugins-official}/external_plugins/playwright"
  inputs.claude-superpowers.outPath
  inputs.claude-ponytail.outPath
  # shortcut: Cavecrew model rewrites need writable agents; package overrides if used.
  inputs.claude-caveman.outPath
  inputs.claude-ui-ux-pro-max.outPath
  "${inputs.codex-plugin-cc}/plugins/codex"
]
