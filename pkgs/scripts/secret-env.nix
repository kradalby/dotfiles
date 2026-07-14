# secret-env [-v] VAR=PATH [VAR=PATH ...] — resolve many secrets in PARALLEL and
# print `export VAR=value` lines (shell-quoted) for `eval`. Wraps `secret`, so it
# inherits setec-first / 1Password-fallback resolution and the -v trace.
#   eval "$(secret-env TF_VAR_a=infra/a TF_VAR_b=dev/b)"
# With no args it reads `VAR PATH` pairs (one per line; # comments ok) from stdin,
# which is what the `secret_env` direnv helper uses.
{ pkgs }:
let
  secret = import ./secret.nix { inherit pkgs; };
in
pkgs.writeShellApplication {
  name = "secret-env";
  runtimeInputs = [
    secret
    pkgs.coreutils
  ];
  text = ''
    verbose=()
    if [ "''${1:-}" = "-v" ] || [ "''${1:-}" = "--verbose" ]; then
      verbose=(-v)
      shift
    fi

    # VAR/PATH pairs: from args (VAR=PATH) or, if none, stdin (VAR PATH per line).
    vars=()
    paths=()
    if [ "$#" -gt 0 ]; then
      for pair in "$@"; do
        vars+=("''${pair%%=*}")
        paths+=("''${pair#*=}")
      done
    else
      while read -r var path _; do
        [ -n "''${var:-}" ] || continue
        case "$var" in \#*) continue ;; esac
        vars+=("$var")
        paths+=("$path")
      done
    fi
    [ "''${#vars[@]}" -gt 0 ] || {
      echo "usage: secret-env [-v] VAR=PATH ...  (or VAR PATH lines on stdin)" >&2
      exit 1
    }

    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT

    # fan out: one `secret` per pair, concurrently. value -> per-job file;
    # the -v trace / errors inherit the terminal's stderr.
    pids=()
    for i in "''${!vars[@]}"; do
      secret "''${verbose[@]}" "''${paths[i]}" > "$tmp/$i" &
      pids[i]=$!
    done

    # collect: emit an export per resolved secret; fail loudly on any miss.
    # %q shell-quotes so `eval` is injection-safe; $(cat) strips the trailing
    # newline exactly like $(secret X) does today.
    rc=0
    for i in "''${!vars[@]}"; do
      if wait "''${pids[i]}"; then
        printf 'export %s=%q\n' "''${vars[i]}" "$(cat "$tmp/$i")"
      else
        echo "secret-env: failed to resolve ''${vars[i]}" >&2
        rc=1
      fi
    done
    exit $rc
  '';
}
