# Repository Guidelines

## Conventions (read first)

Before changing anything, read [`docs/conventions/`](docs/conventions/) — the
`README.md` index, the file for the stack you're touching, and
[`services.md`](docs/conventions/services.md) for anything you run on the fleet
(Tailscale reachability + Prometheus observability + backups). Follow them. If a
change would contradict a convention, or you notice one that's missing, wrong, or
stale, **propose an update to the convention doc in the same change** rather than
silently diverging.

## Project Structure & Module Organization

The flake root (`flake.nix` plus helpers in `lib/box.nix`) stitches together the major layouts:

- `common/`: shared NixOS/darwin modules, reusable service fragments, or opinionated defaults that multiple hosts import.
- `modules/`: bespoke modules packaged like upstream Nix modules (e.g., `restic-jobs.nix`, `tailscale-proxy.nix`) and consumed by hosts or shared configs.
- `machines/<hostname>/`: full host manifests plus any host-only helper files (systemd units, launchd definitions, secret glue). Keep per-host docs in-line here to limit blast radius.
- `profiles/`: opt-in host profiles (e.g. `server.nix`) layered on top of `common/base.nix`.
- `pkgs/`: overlays, derivations, and helper scripts (`overlays/`, `home-packages.nix`, `scripts/`) that extend upstream nixpkgs.
- `home/` and `rc/`: user-mode dotfiles and Home Manager modules; they feed into macOS and Linux hosts alike.
- `checks/`: `nix flake check` derivations (prometheus rule tests, monitoring coverage, VM tests).
- `metadata/`: small, curated datasets (versions, pinning info).
- `docs/`: binding conventions (`docs/conventions/`).
- `misc/`: non-nix artifacts for physical devices (e.g. the esp8266 moisture sensor).
- `secrets/`: agenix payloads plus `secrets/secrets.nix` for key distribution; never drop plaintext into the repo.
  Maintaining these boundaries keeps it obvious whether a change affects every host or just one machine.

## Build, Test, and Development Commands

- `direnv allow` or `nix develop` loads the flake dev shell (defined in `flake.nix`) with the formatters and helper CLIs it declares.
- `nix flake check` evaluates `nixosConfigurations`, packages, and the bespoke checks (x86_64-linux); garnix runs the same checks + host builds in CI. Darwin is validated locally via `darwin-rebuild`. Run the check before pushing.
- `nixos-rebuild test --flake .#<hostname>` applies changes to a NixOS target and `darwin-rebuild switch --flake .#<hostname>` does the same for macOS.
- `nix build .#packages.${system}.<name>` exercises individual packages; scripts under `pkgs/scripts/` should remain runnable once Home Manager syncs.
- Prefer Nix-native helpers when fetching or deploying: `nix-prefetch-git` for pinning sources, `colmena apply` for multi-host rollouts, `nurl <url>` for fetcher snippets, and `nix-init` for scaffolding new derivations.

## Reading CI Logs

`garnixlogs` serves garnix CI output as plain text on the tailnet. No auth, no token, no `direnv`, no setec — reach for it before the garnix API.

```sh
curl -s http://garnixlogs/<repo>                 # recent commits, newest first
curl -s "http://garnixlogs/$(git rev-parse HEAD)" # summary + every failed build's log
curl -s http://garnixlogs/<build-id>              # one build's log
curl -sN "http://garnixlogs/<build-id>?follow"    # stream until it finishes
```

Query flags: `?follow` stream · `?all` list successes too · `?ansi` keep colour escapes · `?ts` prefix timestamps. A bare repo name assumes owner `kradalby`; `owner/repo` is explicit. Commit hashes must be the **full 40 characters** — garnix rejects abbreviated ones, which is why the repo listing prints them in full. Private repos work: the service holds the token, so the tailnet ACL is the only access control.

Only if garnixlogs itself is down, go to the API directly — and note that `$GARNIX_TOKEN` is **not** a Bearer token. It is the Basic-auth password for `POST /api/auth/jwt`, which mints the 1h JWT every other endpoint wants. Sent as a Bearer token it does not fail; it reads as anonymous, which answers on public repos and returns a misleading "not found" on private ones. Check `/api/whoami` before believing a 404.

## Coding Style & Naming Conventions

All formatting goes through `nix fmt` (treefmt: nixfmt-rfc-style for Nix, gofumpt for Go, prettier for Markdown, shfmt `-i 2 -ci` for shell — see `docs/conventions/nix.md`); `prek` runs it plus `shellcheck` and the pre-commit builtins, and CI enforces the same via `checks.x86_64-linux.formatting`. Go code lints with the repo-root `.golangci.yaml`. Favor 2-space indentation, descriptive attribute names (`snake_case` in Nix, hyphen-case for scripts), and keep defaults in `common/` while recording host-specific tweaks inside the target `machines/<hostname>/` module. Run `statix` and `deadnix` before large refactors to catch style regressions and unused definitions.

## Testing Guidelines

`nix flake check` is the canonical smoke test; fail fast if a change breaks evaluation on any platform. Follow up with `prek run --all-files` to exercise the YAML/JSON linters, Markdown formatter, and shell analyzers. For service changes or new hosts, run the relevant deploy command (`nixos-rebuild test --flake .#<hostname>` or `darwin-rebuild switch`) and note the outcome in your PR description. Keep fixtures and helper scripts beside the module they verify (`modules/restic-jobs.nix` <-> `machines/<hostname>/restic.nix`).

## Commit & Pull Request Guidelines

Follow the existing log style of `component: imperative summary` (`meta: move versions into one file`, `nix: flake update`, etc.). Squash fixups locally, write body text only when extra context is needed, and reference any issue or host touched. Every PR should list the validation commands you ran (`flake check`, `nixos-rebuild test .#<hostname>`, etc.), highlight secrets or keys that changed, and attach screenshots/logs for UI-facing adjustments. Draft PRs are encouraged for multi-host migrations so others can parallelize validation.

## Secrets & Configuration Safety

Never commit plaintext credentials; instead edit `secrets/*.age` via `ragenix --rules secrets/secrets.nix -e secrets/<name>.age` (ragenix is on `PATH` via home-manager; the `--rules` flag lets you run it from the repo root) so recipients from `secrets/secrets.nix` remain authoritative. Collect new host keys with `ssh-keyscan -t ed25519 <host>` before adding them to `secrets/secrets.nix` or ragenix’ recipients; this keeps age policies in sync with reality. New services must declare their secret inputs in the target host’s module (and document ownership inline), and any shared Tailscale/Restic keys should be rotated before expiry. Treat `.env` only for short-lived experiments—persistent values belong in agenix and must be referenced through the module system.
