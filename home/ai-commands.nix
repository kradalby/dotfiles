{
  config,
  lib,
  pkgs,
  ...
}:
let
  commandDirectory = ../rc/claude/commands;

  # Claude and OpenCode consume these files directly. Codex and Hermes use the
  # Agent Skills standard, so wrap the same source without duplicating prompts.
  commandSkills =
    lib.mapAttrs'
      (
        fileName: _:
        let
          skillName = lib.removeSuffix ".md" fileName;
          lines = lib.splitString "\n" (builtins.readFile (commandDirectory + "/${fileName}"));
          takeUntil =
            predicate: remaining:
            if remaining == [ ] || predicate (builtins.head remaining) then
              [ ]
            else
              [ (builtins.head remaining) ] ++ takeUntil predicate (builtins.tail remaining);
          dropThrough =
            predicate: remaining:
            if remaining == [ ] then
              [ ]
            else if predicate (builtins.head remaining) then
              builtins.tail remaining
            else
              dropThrough predicate (builtins.tail remaining);
          frontmatter = takeUntil (line: line == "---") (builtins.tail lines);
          field =
            name:
            let
              prefix = "${name}: ";
              line = lib.findFirst (lib.hasPrefix prefix) null frontmatter;
            in
            if line == null then null else lib.removePrefix prefix line;
          description = field "description";
          argumentHint = field "argument-hint";
          body = lib.concatStringsSep "\n" (dropThrough (line: line == "---") (builtins.tail lines));
        in
        lib.nameValuePair ".agents/skills/${skillName}/SKILL.md" {
          text =
            if description == null then
              throw "${fileName} must define a description in its frontmatter"
            else
              ''
                ---
                name: ${skillName}
                description: ${builtins.toJSON description}
                ---

                # ${skillName}

                This skill is generated from `rc/claude/commands/${fileName}`.
                Treat text supplied after the skill name as `$ARGUMENTS` wherever
                that placeholder appears below. Execute shell interpolation directives
                (`!` followed by a backtick-delimited command) at invocation time and
                use their output at that location.
                ${lib.optionalString (argumentHint != null) "Expected arguments: ${argumentHint}"}

                ${body}
              '';
        }
      )
      (
        lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".md" name) (
          builtins.readDir commandDirectory
        )
      );
  # Codex discovers skills under its own CODEX_HOME, not ~/.agents/skills, so
  # publish the same generated content a second time.
  #
  # The whole skill directory is linked, not SKILL.md inside it: codex walks
  # the skills root and skips a symlinked SKILL.md, which is exactly what
  # home-manager writes for a `text` entry. A symlinked directory it follows,
  # so writeTextDir puts a real file behind the link.
  codexSkills = lib.mapAttrs' (
    path: value:
    lib.nameValuePair (lib.removeSuffix "/SKILL.md" (
      lib.replaceStrings [ ".agents/skills/" ] [ ".codex/skills/" ] path
    )) { source = pkgs.writeTextDir "SKILL.md" value.text; }
  ) commandSkills;
in
{
  home.file =
    commandSkills
    // lib.optionalAttrs config.my.packages.ai.codex codexSkills
    // {
      ".claude/commands" = {
        source = commandDirectory;
        recursive = true;
      };
      # Force replaces a copy `rex skill setup` or the Rex app wrote. Not gated on
      # my.packages.ai: some hosts run these agents with those options off.
      ".claude/skills/rex/SKILL.md" = {
        source = "${pkgs.rex-skill}/SKILL.md";
        force = true;
      };
      # OpenCode, Pi and Hermes read this directory.
      ".agents/skills/rex/SKILL.md" = {
        source = "${pkgs.rex-skill}/SKILL.md";
        force = true;
      };
      # Codex follows directory links, but skips a symlinked SKILL.md.
      ".codex/skills/rex" = {
        source = pkgs.rex-skill;
        force = true;
      };
    };

  # The skill only tells an agent to run this command.
  home.packages = [ pkgs.rex-cli ];

  xdg.configFile."opencode/commands".source = pkgs.symlinkJoin {
    name = "opencode-commands";
    paths = [
      commandDirectory
    ]
    ++ lib.optional (
      config.my.packages.ai.enable && config.my.packages.ai.opencode
    ) pkgs.ai-plugins.opencodeCommands;
  };
}
