{ pkgs }:
let
  python = pkgs.python3.withPackages (p: [ p.tomlkit ]);
  migrate = import ../../pkgs/scripts/codex-session-env-migrate.nix { inherit pkgs; };
in
pkgs.runCommand "codex-session-env-test"
  {
    nativeBuildInputs = with pkgs; [
      bash
      coreutils
      jq
      python
      pyright
      ruff
    ];
  }
  ''
    ruff check --select ANN,UP,SIM,B,I --line-length 100 ${../../pkgs/scripts/codex-session-env-migrate.py}
    ruff format --check --line-length 100 ${../../pkgs/scripts/codex-session-env-migrate.py}
    cat > "$TMPDIR/pyrightconfig.json" <<'JSON'
    {"typeCheckingMode": "strict"}
    JSON
    pyright --pythonpath ${python}/bin/python3 --project "$TMPDIR/pyrightconfig.json" ${../../pkgs/scripts/codex-session-env-migrate.py}
    bash ${./test.sh} \
      ${../../pkgs/scripts/codex-nix-dev-env-hook.sh} \
      ${../../pkgs/scripts/codex-session-env.sh} \
      ${migrate}/bin/codex-session-env-migrate
    touch "$out"
  ''
