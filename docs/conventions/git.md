# Git, prek, CI, testing

## Commits

- `package: imperative summary` — lowercase, no period, no `feat:`/`chore:`. e.g. `db: scope DestroyUser to target user`.
- Scopes seen: `ci:`, `nix:`, `deps:`, `test:`, `build:`, or the package/domain.
- Body only when _why_ isn't obvious. Footer `Updates/Fixes #N`. Generated code committed separately from hand-written changes.
- Prefer new commits over history rewrites.

## prek (pre-commit, Rust reimpl)

- `prek run --all-files` before commit; CI runs the same with `fetch-depth: 0`. Config is `.pre-commit-config.yaml` (consumed by prek or pre-commit).
- Builtins: trailing-whitespace, end-of-file-fixer, check-{json,yaml,toml,merge-conflict}, check-added-large-files, detect-private-key, mixed-line-ending.
- Local hooks (from the devShell), per tsnixcache:
  - `treefmt --fail-on-change`
  - `golangci-lint run --new-from-rev=HEAD~1 --fix`
  - `go test -short -timeout=5m ./...`
  - `nix build .#checks.<sys>.{build,golangci-lint,formatting}` gated on `flake.nix`/`go.{mod,sum}` changes
  - `go run ./cmd/vendorhash check` gated on `go.{mod,sum}`/`flakehashes.json`
- Exclude `^gen/`, `^testdata/`, `result/`, `.direnv/`.

## GitHub Actions (current shape — wc3ts)

- Nix install `NixOS/nix-installer-action`, cache `Mic92/hestia/action`, checkout `actions/checkout` — all pinned to a commit SHA with a trailing `# vN` comment.
- Concurrency group cancels superseded runs.
- Each job calls one check: `nix build -L .#checks.<sys>.<name>` (build, gotest, golangci-lint, formatting) + a `nixos-module` eval job for services. No `nix develop` needed in gate jobs.
- Deps: dependabot (gomod + github-actions, grouped) and/or scheduled flake-lock update PRs.

## Testing workflow

- Unit tests mandatory for features; run via flake checks / apps.
- `go test` flags through flake-checks: `-race` (opt-in `goRace`), `-skip` (`goSkip`), `-short` in hooks.
- Golden / `testdata/` for complex output. Heavy integration matrix (SQLite + PostgreSQL, Docker) only where warranted — see headscale.

## Copy from

- `wc3ts` — current CI workflows (hestia + nix-installer, SHA-pinned)
- `tsnixcache` — `.pre-commit-config.yaml`, `treefmt.toml`
- `git log --author=kradalby` (e.g. in headscale) — commit voice, your commits only
