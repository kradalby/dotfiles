{ inputs, pkgs }:
let
  official = inputs.claude-plugins-official;
  ponytail = inputs.claude-ponytail;
  caveman = inputs.claude-caveman;
  superpowers = inputs.claude-superpowers;
  uiUx = inputs.claude-ui-ux-pro-max;
  # Codex does not load Caveman's inline Claude hooks or its repo-local config.
  cavemanCodex =
    let
      manifest = (pkgs.formats.json { }).generate "caveman-codex-plugin.json" (
        (builtins.fromJSON (builtins.readFile "${caveman}/.claude-plugin/plugin.json"))
        // {
          skills = "./skills/";
          hooks = "./.codex/hooks.json";
          interface.displayName = "Caveman";
        }
      );
      hooks = (pkgs.formats.json { }).generate "caveman-codex-hooks.json" {
        hooks.SessionStart = [
          {
            matcher = "startup|resume";
            hooks = [
              {
                type = "command";
                command = ''${pkgs.nodejs_26}/bin/node "$PLUGIN_ROOT/.codex/codex-sessionstart.js"'';
                timeout = 5;
              }
            ];
          }
        ];
      };
    in
    pkgs.runCommand "caveman-codex-plugin" { } ''
      # Codex skips symlinked plugin files when copying them into its cache.
      mkdir -p $out
      cp -RL ${caveman}/. $out/
      chmod -R u+w $out
      mkdir -p $out/.codex-plugin
      cp ${manifest} $out/.codex-plugin/plugin.json
      cp ${hooks} $out/.codex/hooks.json
    '';
  codexSources = {
    claude-plugins-official = {
      frontend-design = "${official}/plugins/frontend-design";
      github = "${official}/external_plugins/github";
      playwright = "${official}/external_plugins/playwright";
      superpowers = superpowers.outPath;
    };
    ponytail.ponytail = ponytail.outPath;
    caveman.caveman = cavemanCodex;
    ui-ux-pro-max-skill.ui-ux-pro-max = uiUx.outPath;
  };
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
{
  claude = [
    goplsPlugin
    "${inputs.claude-plugins-official}/plugins/code-simplifier"
    "${inputs.claude-plugins-official}/plugins/frontend-design"
    "${inputs.claude-plugins-official}/plugins/code-review"
    "${inputs.claude-plugins-official}/external_plugins/github"
    "${inputs.claude-plugins-official}/external_plugins/playwright"
    superpowers.outPath
    ponytail.outPath
    # shortcut: Cavecrew model rewrites need writable agents; package overrides if used.
    caveman.outPath
    uiUx.outPath
    "${inputs.codex-plugin-cc}/plugins/codex"
  ];

  # Keep marketplace identities so existing installs are refreshed in place.
  codex = pkgs.lib.mapAttrs (marketplace: plugins: {
    names = builtins.attrNames plugins;
    root =
      let
        catalog = (pkgs.formats.json { }).generate "marketplace.json" {
          name = marketplace;
          plugins = pkgs.lib.mapAttrsToList (name: _: {
            inherit name;
            source = {
              source = "local";
              path = "./plugins/${name}";
            };
            policy = {
              installation = "INSTALLED_BY_DEFAULT";
              authentication = "ON_USE";
            };
            category = "Productivity";
          }) plugins;
        };
      in
      pkgs.runCommand "codex-marketplace-${marketplace}" { } ''
        mkdir -p $out/.agents/plugins $out/plugins
        ln -s ${catalog} $out/.agents/plugins/marketplace.json
        ${pkgs.lib.concatStringsSep "\n" (
          pkgs.lib.mapAttrsToList (name: source: ''
            ln -s ${source} $out/plugins/${name}
          '') plugins
        )}
      '';
  }) codexSources;

  opencode = {
    ponytail = pkgs.writeText "ponytail.js" ''
      export { default } from '${ponytail}/.opencode/plugins/ponytail.mjs';
    '';
    superpowers = pkgs.writeText "superpowers.js" ''
      export { default } from '${superpowers}/.opencode/plugins/superpowers.js';
    '';
    caveman = pkgs.writeText "caveman.js" ''
      export { CavemanPlugin } from '${caveman}/src/plugins/opencode/plugin.js';
    '';
  };

  opencodeSkills =
    pkgs.lib.foldl'
      (
        skills: directory:
        skills
        // pkgs.lib.mapAttrs (name: _: "${directory}/${name}") (
          pkgs.lib.filterAttrs (_: type: type == "directory") (builtins.readDir directory)
        )
      )
      { }
      [
        "${caveman}/skills"
        "${uiUx}/.claude/skills"
        "${official}/plugins/frontend-design/skills"
      ];

  opencodeCommands = "${caveman}/src/plugins/opencode/commands";
  opencodeAgents =
    pkgs.runCommand "cavecrew-opencode-agents" { nativeBuildInputs = [ pkgs.nodejs_26 ]; }
      ''
        mkdir -p $out
        node - ${caveman} $out <<'JS'
        const fs = require('node:fs');
        const [source, output] = process.argv.slice(2);
        const { transformOpencodeAgentFrontmatter } = require(source + '/installer/lib/opencode-agent.js');
        for (const name of ['cavecrew-investigator', 'cavecrew-builder', 'cavecrew-reviewer']) {
          fs.writeFileSync(output + '/' + name + '.md', transformOpencodeAgentFrontmatter(
            fs.readFileSync(source + '/agents/' + name + '.md', 'utf8'), { subagent: true }
          ));
        }
        JS
      '';
}
