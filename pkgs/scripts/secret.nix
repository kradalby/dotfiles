# secret NAME — resolve a secret by canonical name.
#   1. setec over the tailnet via its HTTP API (curl — light, system TLS so no
#      cert workaround, no 45MB setec binary). 1s timeout.
#   2. fallback: direct 1Password if op is installed — offline-capable via the
#      locally cached "ts1p" vault (setec's backend; the "value" field holds the
#      active version). op is NOT a nix dependency; it's used from PATH if found.
# One source of truth: the "ts1p" 1Password vault. setec serves it; op reads it.
{pkgs}:
pkgs.writeShellApplication {
  name = "secret";
  runtimeInputs = [pkgs.curl pkgs.coreutils];
  text = ''
    name=''${1:?usage: secret NAME}
    : "''${SETEC_SERVER:=https://setec.dalby.ts.net}"

    # 1) setec HTTP API. The Sec- header is mandatory (CSRF guard); Value is
    #    base64-encoded JSON. 1s timeout so an unreachable server fails over fast.
    resp=$(curl -fsS --max-time 1 \
      -H 'Content-Type: application/json' \
      -H 'Sec-X-Tailscale-No-Browsers: setec' \
      "$SETEC_SERVER/api/get" \
      --data '{"Name":"'"$name"'"}' 2>/dev/null) || resp=""
    case "$resp" in
      *'"Value":"'*)
        v=''${resp#*\"Value\":\"}
        v=''${v%%\"*}
        if d=$(printf '%s' "$v" | base64 -d 2>/dev/null); then
          printf '%s' "$d"
          exit 0
        fi
        ;;
    esac

    # 2) fallback: direct 1Password (op item get — op:// can't express slash names).
    if command -v op >/dev/null 2>&1; then
      if d=$(op item get "$name" --vault ts1p --fields label=value --reveal 2>/dev/null) \
         && [ -n "$d" ]; then
        printf '%s' "$d"
        exit 0
      fi
    fi

    echo "secret: could not resolve '$name' (setec 1s timeout, op fallback)" >&2
    exit 1
  '';
}
