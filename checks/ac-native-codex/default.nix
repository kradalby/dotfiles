{ pkgs }:
pkgs.runCommand "ac-native-codex-test"
  {
    nativeBuildInputs = with pkgs; [
      bash
      coreutils
      jq
      python3
      ruff
      pyright
      websocat
      herdr
      master.codex
    ];
  }
  ''
    ruff check --select ANN,UP,SIM,B,I ${../../pkgs/scripts/ac-native-tui-test.py}
    ruff format --check --line-length 100 ${../../pkgs/scripts/ac-native-tui-test.py}
    pyright --pythonversion 3.14 --project ${../ac/pyrightconfig.json} ${../../pkgs/scripts/ac-native-tui-test.py}
    python3 ${../../pkgs/scripts/ac-native-tui-test.py} \
      ${../../pkgs/scripts/ac.sh} ${../../pkgs/scripts/herdr-codex.sh}
    touch "$out"
  ''
