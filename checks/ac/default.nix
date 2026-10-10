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
      gnugrep
      jq
      python3
      codex
      ruff
      pyright
      (import ../../pkgs/scripts/ac.nix { inherit pkgs; })
    ];
  }
  ''
    ruff check --select ANN,UP,SIM,B,I ${../../pkgs/scripts/ac-trust-test.py} ${../../pkgs/scripts/ac-thread-test.py}
    ruff format --check --line-length 100 ${../../pkgs/scripts/ac-trust-test.py} ${../../pkgs/scripts/ac-thread-test.py}
    pyright --pythonversion 3.14 --project ${./pyrightconfig.json} ${../../pkgs/scripts/ac-trust-test.py} ${../../pkgs/scripts/ac-thread-test.py}
    bash ${../../pkgs/scripts/ac-lifecycle-test.sh} ${../../pkgs/scripts/ac.sh}
    bash ${../../pkgs/scripts/ac.sh} selftest
    python3 ${../../pkgs/scripts/ac-trust-test.py} ${../../pkgs/scripts/ac.sh}
    python3 ${../../pkgs/scripts/ac-thread-test.py} ${../../pkgs/scripts/ac.sh}
    touch "$out"
  ''
