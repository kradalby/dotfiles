{ lib, ... }:
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
in
{
  home.file = commandSkills // {
    ".claude/commands" = {
      source = commandDirectory;
      recursive = true;
    };
  };

  xdg.configFile."opencode/commands".source = commandDirectory;
}
