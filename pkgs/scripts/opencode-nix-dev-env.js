// Make opencode's shell (AI shell tool + `!` shell mode) adopt the per-directory
// Nix dev env, mirroring the Claude Code nix-dev-env hook. opencode triggers
// `create.before` for every shell command with the target cwd; env set on the
// event applies to that command.
//
// Primary: direnv (.envrc, e.g. `use flake` via nix-direnv).
// Fallback: `nix print-dev-env --json` for a bare flake.nix (no .envrc).
//
// `direnv export json` emits a DIFF against the *current* env, so if opencode
// inherited a direnv state (DIRENV_DIR/DIRENV_DIFF in its environment) it would
// emit nothing. We strip the DIRENV_* vars for the call so direnv always
// computes the full env for the target cwd.
//
// Plain .js, node builtins only, so opencode loads it without a package.json /
// bun install. Auto-discovered from ~/.config/opencode/plugin/.
import { execFile } from "node:child_process";
import { promisify } from "node:util";

const run = promisify(execFile);

// Trimmed stdout, or "" when the command fails.
async function stdout(cmd, args, cwd, env) {
  try {
    // A dev env dump outgrows execFile's default 1 MiB buffer.
    const r = await run(cmd, args, { cwd, env, maxBuffer: 64 << 20 });
    return r.stdout.trim();
  } catch {
    return "";
  }
}

export default {
  id: "nix-dev-env",
  async setup(ctx) {
    await ctx.shell.hook("create.before", async (event) => {
      const cwd = event.cwd;
      if (!cwd) return;

      // direnv first, with any inherited direnv state cleared.
      const clean = { ...process.env };
      for (const k of ["DIRENV_DIR", "DIRENV_DIFF", "DIRENV_WATCHES", "DIRENV_FILE"]) {
        delete clean[k];
      }
      try {
        const text = await stdout("direnv", ["export", "json"], cwd, clean);
        if (text) {
          let merged = 0;
          for (const [k, v] of Object.entries(JSON.parse(text))) {
            if (v === null) continue; // direnv signals "unset" with null
            event.env[k] = String(v);
            merged++;
          }
          if (merged > 0) return;
        }
      } catch {}

      // Fallback: nix dev shell for a bare flake (no .envrc).
      try {
        const text = await stdout("nix", ["print-dev-env", "--json"], cwd, process.env);
        if (text) {
          const vars = JSON.parse(text).variables ?? {};
          for (const [k, v] of Object.entries(vars)) {
            if (v && v.type === "exported" && typeof v.value === "string") {
              event.env[k] = v.value;
            }
          }
        }
      } catch {}
    });
  },
};
