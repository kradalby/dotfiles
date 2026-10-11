# AI plugins

The six source-only flake inputs in `flake.nix` supply every managed client.
`nix flake update` updates their revisions and generated lockfile hashes together;
no separate version or hash pins are maintained.

| Client   | Managed components                                                                                         |
| -------- | ---------------------------------------------------------------------------------------------------------- |
| Claude   | All eleven plugins through Home Manager's native loader, including background instances                    |
| Codex    | Ponytail, Superpowers, Caveman, frontend-design, UI/UX Pro Max, GitHub, and Playwright                     |
| OpenCode | Native Ponytail, Superpowers, and Caveman plugins; Caveman and design skills; Cavecrew agents and commands |

Claude-only LSP, agent, and command packages are not installed as empty Codex
plugins, and the Claude-to-Codex bridge is only installed in Claude.

Codex copies local plugins into its own cache. Home Manager activation replaces a
marketplace registration when its pinned source changes, preserves the existing
marketplace identity, and refreshes every managed plugin even if its version did
not change. Client-owned configuration and other plugins remain intact. Account
connections and hook trust still use Codex's normal setup flow.
Caveman's Codex manifest uses its upstream startup script through `PLUGIN_ROOT`,
so its hook works independently of the session's Git checkout.

OpenCode loads small entrypoints that import the pinned upstream integrations.
Skills retain their upstream directory layout, and Cavecrew agents use the
upstream OpenCode frontmatter converter. User-installed skills and agents can
coexist with these entries.

The source files are immutable. Caveman's optional Claude Cavecrew model rewrites
need a writable override if those environment variables are used.
