{ pkgs, ... }:
let
  python = pkgs.python3.withPackages (p: [ p.tomlkit ]);
in
pkgs.writeScriptBin "codex-session-env-migrate" ''
  #!${python}/bin/python3
  ${builtins.readFile ./codex-session-env-migrate.py}
''
