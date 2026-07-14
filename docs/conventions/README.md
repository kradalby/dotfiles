# kradalby conventions

Starting a new project? Read this file, then the file for your stack.

## Universal rules

- **Reuse over reinvent.** Stop at the first thing that works; promote shared helpers to a shared lib (`kra`), never copy.
- **Refresh before building.** This guide goes stale. Before starting, check the newest toolchain/language release and its notes, the relevant upstream (nixpkgs & `lib`, stdlib, framework changelogs, project issues/forums), _and_ my freshest repo. Adopt new idioms and helpers; don't cargo-cult this file.
- **Comments are terse and explain _why_, not _what_.**
- **Nix-first.** Every repo has a `flake.nix`. Build/test/lint/format are flake outputs, not ad-hoc scripts.
- **All checks go through [`kradalby/flake-checks`](https://github.com/kradalby/flake-checks).** Extend it, don't fork the pattern. CI just calls the checks. → [nix.md](nix.md)
- **Formatting: treefmt, always.** One entrypoint orchestrating every language's formatter (nixfmt-rfc-style, gofumpt + goimports, prettier, shfmt) — no standalone per-tool hooks, no per-repo formatter drift. → [nix.md](nix.md)
- **prek** runs format+lint hooks (`treefmt --fail-on-change` for formatting); `prek run --all-files` before commit. → [git.md](git.md)
- **Commits: `package: imperative summary`** — lowercase, no period, no Conventional-Commits prefixes. → [git.md](git.md)
- **Secrets never in git.** Dev: `.envrc` + 1Password `op read`. Prod: ragenix `age.secrets`. → [secrets.md](secrets.md)
- **No speculative abstraction.** Smallest thing that works; no abstraction for a single caller.

## Per-stack

[Go](go.md) · [Nix](nix.md) · [Git / CI / prek](git.md) · [Secrets](secrets.md)
· [Web / Frontend](frontend.md) · [Terraform](terraform.md) · [Services](services.md)
· [Elm](elm.md) · [Python](python.md) · [Swift](swift.md)

## Reference repos (copy from these)

- Go service + everything: **headscale** · small Go lib: **kra**, **nefit-go**
- ffcli + koanf config: **gigahost-go** · current flake + CI: **wc3ts**, **tsnixcache**, **z2m-homekit**
- flake-checks itself: **flake-checks**
- Server-rendered UI: **nefit-homekit/web**, **tasmota-homekit** · frontend-via-nix: **hugin**
- Machine config / nix patterns: **dotfiles**
