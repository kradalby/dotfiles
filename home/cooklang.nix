# Cooklang recipes for agents: the `cook` MCP server plus the upstream skills.
# Set only on hosts that hold a synced recipe folder.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  recipes = config.my.cooklang.recipes;
  # Without COOK_RECIPES_DIR the server takes the client's workspace roots or
  # cwd, i.e. whatever project the agent started in. No registration carries
  # env; set-default still lets a client override.
  wrapper = pkgs.symlinkJoin {
    name = "cook-mcp-wrapped";
    paths = [ pkgs.cook-mcp ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/cook-mcp --set-default COOK_RECIPES_DIR ${lib.escapeShellArg recipes}
    '';
  };
  skillsDir = "${pkgs.cook-mcp.src}/skills";
  skills = builtins.attrNames (
    lib.filterAttrs (_: type: type == "directory") (builtins.readDir skillsDir)
  );
  codex = config.my.packages.ai.codex;
in
{
  options.my.cooklang.recipes = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "Synced Cooklang recipe folder; enables the cook MCP server and Cooklang skills.";
  };

  config = lib.mkIf (recipes != null) {
    home.packages = [ wrapper ];

    home.file = lib.mkMerge (
      map (
        n:
        {
          ".claude/skills/${n}/SKILL.md".source = "${skillsDir}/${n}/SKILL.md";
          ".agents/skills/${n}/SKILL.md".source = "${skillsDir}/${n}/SKILL.md";
        }
        # Codex follows directory links, but skips a symlinked SKILL.md.
        // lib.optionalAttrs codex { ".codex/skills/${n}".source = "${skillsDir}/${n}"; }
      ) skills
    );
  };
}
