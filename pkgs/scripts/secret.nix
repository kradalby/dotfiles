# secret [-v] NAME — resolve a secret by canonical name.
#   1. setec over the tailnet via its HTTP API (curl — light, system TLS so no
#      cert workaround, no 45MB setec binary). 1s timeout.
#   2. fallback: direct 1Password if op is installed — offline-capable via the
#      locally cached "ts1p" vault (setec's backend; the "value" field holds the
#      active version). op is NOT a nix dependency; it's used from PATH if found.
# -v/--verbose traces which source answered, to stderr (stdout stays the value).
# One source of truth: the "ts1p" 1Password vault. setec serves it; op reads it.
{ pkgs }:
pkgs.writeShellApplication {
  name = "secret";
  runtimeInputs = [
    pkgs.curl
    pkgs.coreutils
    pkgs.findutils
  ];
  text = ''
    verbose=0
    case "''${1:-}" in
      -v | --verbose)
        verbose=1
        shift
        ;;
    esac
    name=''${1:?usage: secret [-v] NAME}
    : "''${SETEC_SERVER:=https://setec.dalby.ts.net}"

    # -v: trace resolution to stderr; stdout stays the value, so $(secret -v X) is safe.
    log() { [ "$verbose" = 1 ] && printf 'secret: %s\n' "$*" >&2 || true; }

    # 1) setec HTTP API. The Sec- header is mandatory (CSRF guard); Value is
    #    base64-encoded JSON. connect-timeout 1s = fast failover when setec is
    #    unreachable; max-time 12s leaves room for a cold 1Password unlock plus
    #    the parallel reads it gates (secret-env) to finish from setec rather
    #    than cancelling and falling back to 1Password.
    log "$name: querying setec ($SETEC_SERVER)"
    resp=$(curl -fsS --connect-timeout 1 --max-time 12 \
      -H 'Content-Type: application/json' \
      -H 'Sec-X-Tailscale-No-Browsers: setec' \
      "$SETEC_SERVER/api/get" \
      --data '{"Name":"'"$name"'"}' 2>/dev/null) || resp=""
    case "$resp" in
      *'"Value":"'*)
        v=''${resp#*\"Value\":\"}
        v=''${v%%\"*}
        if d=$(printf '%s' "$v" | base64 -d 2>/dev/null); then
          log "$name: loaded from setec"
          printf '%s' "$d"
          exit 0
        fi
        ;;
    esac
    log "$name: not served by setec (unreachable or miss), trying 1Password"

    # 2) fallback: direct 1Password (op item get — op:// can't express slash
    #    names). Under a parallel secret_env load, serialize only a cheap unlock
    #    probe behind a mkdir lock so 1Password prompts for approval ONCE: the
    #    first probe hits a locked app and prompts, the rest land in op's grace
    #    window and return at once. The slow `op item get` reads happen AFTER the
    #    lock, so they run concurrently. A stale lock (>60s, e.g. an interrupted
    #    run) is reaped.
    if command -v op >/dev/null 2>&1; then
      lock=''${TMPDIR:-/tmp}/secret-op.lock
      i=0
      while [ "$i" -lt 400 ]; do
        if mkdir "$lock" 2>/dev/null; then
          op vault get ts1p >/dev/null 2>&1 || true
          rmdir "$lock" 2>/dev/null
          break
        fi
        [ -n "$(find "$lock" -prune -mmin +1 2>/dev/null)" ] && rmdir "$lock" 2>/dev/null
        i=$((i + 1))
        sleep 0.1
      done
      log "$name: querying 1Password"
      d=$(op item get "$name" --vault ts1p --fields label=value --reveal 2>/dev/null) || d=""
      if [ -n "$d" ]; then
        log "$name: loaded from 1Password"
        printf '%s' "$d"
        exit 0
      fi
    fi

    log "$name: not found in setec or 1Password"
    echo "secret: could not resolve '$name' (setec 1s timeout, op fallback)" >&2
    exit 1
  '';
}
