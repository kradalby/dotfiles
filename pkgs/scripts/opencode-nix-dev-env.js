// Make opencode's shell (AI bash tool + `!` shell mode) adopt the per-directory
// Nix dev env, mirroring the Claude Code nix-dev-env hook. opencode triggers
// `shell.env` for every command with the target cwd; we return the env to merge
// (opencode applies it as { ...process.env, ...output.env }).
//
// Primary: direnv (.envrc, e.g. `use flake` via nix-direnv).
// Fallback: `nix print-dev-env --json` for a bare flake.nix (no .envrc).
//
// `direnv export json` emits a DIFF against the *current* env, so if opencode
// inherited a direnv state (DIRENV_DIR/DIRENV_DIFF in its environment) it would
// emit nothing. We strip the DIRENV_* vars for the call so direnv always
// computes the full env for the target cwd.
//
// Plain .js, no imports, so opencode loads it without a package.json / bun
// install. Auto-discovered from ~/.config/opencode/plugin/.
export const NixDevEnv = async ({ $ }) => ({
  "shell.env": async (input, output) => {
    const cwd = input.cwd;
    if (!cwd) return;

    // direnv first, with any inherited direnv state cleared.
    try {
      const r =
        await $`env -u DIRENV_DIR -u DIRENV_DIFF -u DIRENV_WATCHES -u DIRENV_FILE direnv export json`
          .cwd(cwd)
          .quiet()
          .nothrow();
      const text = r.stdout.toString().trim();
      if (r.exitCode === 0 && text) {
        const env = JSON.parse(text);
        let merged = 0;
        for (const [k, v] of Object.entries(env)) {
          if (v === null) continue; // direnv signals "unset" with null
          output.env[k] = String(v);
          merged++;
        }
        if (merged > 0) return;
      }
    } catch {}

    // Fallback: nix dev shell for a bare flake (no .envrc).
    try {
      const r = await $`nix print-dev-env --json`.cwd(cwd).quiet().nothrow();
      const text = r.stdout.toString().trim();
      if (r.exitCode === 0 && text) {
        const vars = JSON.parse(text).variables ?? {};
        for (const [k, v] of Object.entries(vars)) {
          if (v && v.type === "exported" && typeof v.value === "string") {
            output.env[k] = v.value;
          }
        }
      }
    } catch {}
  },
});
