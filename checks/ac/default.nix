{
  pkgs,
  codex ? pkgs.master.codex,
}:
pkgs.runCommand "ac-test"
  {
    nativeBuildInputs = with pkgs; [
      bash
      coreutils
      gnused
      jq
      python3
      codex
      ruff
      pyright
      (import ../../pkgs/scripts/ac.nix { inherit pkgs; })
    ];
  }
  ''
    ruff check --select ANN,UP,SIM,B,I ${../../pkgs/scripts/ac-trust-test.py}
    ruff format --check --line-length 100 ${../../pkgs/scripts/ac-trust-test.py}
    pyright --pythonversion 3.14 --project ${./pyrightconfig.json} ${../../pkgs/scripts/ac-trust-test.py}
    bash ${../../pkgs/scripts/ac.sh} selftest
    python3 ${../../pkgs/scripts/ac-trust-test.py} ${../../pkgs/scripts/ac.sh}
    touch "$out"
  ''
