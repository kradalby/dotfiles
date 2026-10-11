{
  config,
  lib,
  pkgs,
  ...
}:
let
  plugins = pkgs.ai-plugins;
  codexInstall = import ../pkgs/scripts/codex-plugin-install.nix { inherit pkgs; };
in
{
  home.activation.codexPlugins = lib.mkIf (config.my.mutableJson ? codex) (
    lib.hm.dag.entryAfter [ "writeBoundary" "mutableJson" "codexSessionEnvironment" ] (
      lib.concatStrings (
        lib.mapAttrsToList (_: source: ''
          run ${codexInstall}/bin/codex-plugin-install ${source.root}
        '') plugins.codex
      )
    )
  );

  xdg.configFile = lib.mkIf (config.my.packages.ai.enable && config.my.packages.ai.opencode) (
    lib.mapAttrs' (
      name: source: lib.nameValuePair "opencode/plugins/${name}.js" { inherit source; }
    ) plugins.opencode
    // lib.mapAttrs' (
      name: source: lib.nameValuePair "opencode/skills/${name}" { inherit source; }
    ) plugins.opencodeSkills
    //
      lib.genAttrs
        (map (name: "opencode/agents/${name}.md") [
          "cavecrew-investigator"
          "cavecrew-builder"
          "cavecrew-reviewer"
        ])
        (name: {
          source = "${plugins.opencodeAgents}/${builtins.baseNameOf name}";
        })
  );
}
