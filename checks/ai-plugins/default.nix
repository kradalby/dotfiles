{ pkgs }:
let
  install = import ../../pkgs/scripts/codex-plugin-install.nix { inherit pkgs; };
  sources = (pkgs.formats.json { }).generate "ai-plugin-sources.json" {
    codex = pkgs.ai-plugins.codex;
    opencode = pkgs.ai-plugins.opencode;
    skills = pkgs.ai-plugins.opencodeSkills;
    agents = pkgs.ai-plugins.opencodeAgents;
    commands = pkgs.ai-plugins.opencodeCommands;
  };
in
pkgs.runCommand "ai-plugin-tests"
  {
    nativeBuildInputs = [
      pkgs.python3
      pkgs.nodejs_26
      pkgs.ruff
      pkgs.pyright
    ];
  }
  ''
    ruff check --select ANN,UP,SIM,B,I --line-length 100 ${./test.py}
    ruff format --check --line-length 100 ${./test.py}
    echo '{"typeCheckingMode":"strict"}' > "$TMPDIR/pyrightconfig.json"
    pyright --pythonpath ${pkgs.python3}/bin/python3 --project "$TMPDIR/pyrightconfig.json" ${./test.py}
    python3 ${./test.py} ${pkgs.master.codex}/bin/codex ${pkgs.master.opencode}/bin/opencode ${install}/bin/codex-plugin-install ${sources}
    touch $out
  ''
