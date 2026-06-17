# Make Claude Code's (non-interactive) Bash tool adopt per-directory dev envs.
# Primary: direnv (.envrc, e.g. `use flake` via nix-direnv).
# Fallback (no usable .envrc): `nix print-dev-env` for the directory's flake.
[ -n "$CLAUDE_ENV_FILE" ] || exit 0
has() { command -v "$1" >/dev/null 2>&1; }

# Claude passes event JSON on stdin; honor the directory it reports.
payload="$(cat)"
dir="$(printf '%s' "$payload" | jq -r '.new_cwd // .cwd // empty' 2>/dev/null)"
[ -n "$dir" ] || dir="$(printf '%s' "$payload" \
  | grep -oE '"(new_cwd|cwd)"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n1 \
  | sed -E 's/.*"([^"]*)"$/\1/')"
[ -n "$dir" ] && [ -d "$dir" ] && cd "$dir" || true

SNAP="${CLAUDE_ENV_FILE}.snapshot"
# CLAUDE_ENV_FILE is append-only and shared between hooks: add the source line once.
grep -qF "$SNAP" "$CLAUDE_ENV_FILE" 2>/dev/null \
  || printf '. "%s"\n' "$SNAP" >> "$CLAUDE_ENV_FILE"

# Rebuild the snapshot from scratch each call so project transitions are clean.
{
  loaded=""
  if has direnv && [ -f .envrc ]; then
    out="$(direnv export bash 2>/dev/null)"
    [ -n "$out" ] && { printf '%s\n' "$out"; loaded=1; }
  fi
  if [ -z "$loaded" ] && [ -f flake.nix ] && has nix; then
    cdir="${XDG_CACHE_HOME:-$HOME/.cache}/claude-code-nix-env"
    mkdir -p "$cdir"
    cf="$cdir/$(printf '%s' "$PWD" | sha256sum | cut -c1-32)"
    stale=1
    if [ -f "$cf" ]; then
      stale=0
      [ flake.nix -nt "$cf" ] && stale=1
      [ -f flake.lock ] && [ flake.lock -nt "$cf" ] && stale=1
    fi
    # Emit a single POSIX `export PATH` line, not raw `nix print-dev-env`
    # bash. The raw dump assigns readonly specials (e.g. LINENO) that abort
    # the source under zsh, so PATH (and the dev tools) never apply. One
    # quoted export prepended to $PATH is shell-agnostic (bash/zsh/POSIX)
    # and OS-agnostic.
    # ponytail: PATH only; widen the jq to other exported vars if a dev
    # shell sets env (CGO flags, PKG_CONFIG_PATH) the Bash tool needs.
    if [ "$stale" = 1 ]; then
      nix print-dev-env --json 2>/dev/null \
        | jq -r '.variables.PATH.value // empty | "export PATH=\(.|@sh):\"$PATH\""' \
        > "$cf"
      [ -s "$cf" ] || rm -f "$cf"
    fi
    [ -s "$cf" ] && cat "$cf"
  fi
  echo "true"   # guard: export lines end in ';'; a bare trailing ';' would form '; &&'
} > "$SNAP"
