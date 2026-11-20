# Repository Guidelines

## Conventions (read first)

Read [`docs/conventions/README.md`](docs/conventions/README.md) before starting
work, then the convention file for the stack you're touching. For anything run
on the fleet, also read [`services.md`](docs/conventions/services.md)
(Tailscale reachability + Prometheus observability + backups). Follow them.

Conventions are curated exclusively by kradalby. Agents must never add, edit, or
delete files in `docs/conventions/`. Keep service and implementation documentation
beside the relevant module or host. If a convention is missing, stale, or conflicts
with a requested change, flag it to kradalby without modifying the conventions.

## Commands

- `nix flake check`: canonical check (x86_64-linux); garnix runs the same plus host builds. Darwin is validated locally via `darwin-rebuild`. Run before pushing.
- `nix fmt` formats everything (treefmt); `prek run --all-files` adds shellcheck and the pre-commit builtins. CI enforces `checks.x86_64-linux.formatting`.
- `nixos-rebuild test --flake .#<hostname>` / `darwin-rebuild switch --flake .#<hostname>` apply to a host. For service changes or new hosts, run it and note the outcome in the PR.
- `nix build .#packages.${system}.<name>` builds one package.
- `statix` and `deadnix` before large refactors.
- Fetching/deploying: `nurl <url>` or `nix-prefetch-git` for pins, `nix-init` for new derivations, `nh os switch . --target-host root@<host>` to deploy (see `.agents/skills/deploy`).

## Layout rules

- Shared defaults go in `common/`; host-specific tweaks and per-host docs in `machines/<hostname>/`, so blast radius stays obvious.
- Fixtures and helper scripts live beside the module they verify (`modules/restic-jobs.nix` <-> `machines/<hostname>/restic.nix`).

## Reading and Re-running CI

`garnixlogs` serves garnix CI output as plain text on the tailnet. No auth, no token, no `direnv`, no setec — reach for it before the garnix API.

```sh
curl -s http://garnixlogs/<repo>                 # recent commits, newest first
curl -s "http://garnixlogs/$(git rev-parse HEAD)" # summary + every failed build's log
curl -s http://garnixlogs/<build-id>              # one build's log
curl -sN "http://garnixlogs/<build-id>?follow"    # stream until it finishes
curl -s -X POST "http://garnixlogs/<sha>/retry"   # re-run every garnix check on a commit
```

A retry is the only restart agents have: GitHub accepts a check-suite rerequest from the garnix App alone, so a `gh` token cannot do it, and garnixlogs makes the request as the App. Read the failed log first, since a retry only helps flakes and infrastructure faults. The whole commit reruns: passed builds come back from cache, and actions fire again, so a green retry of a default-branch commit can deploy.

Query flags: `?follow` stream · `?all` list successes too · `?ansi` keep colour escapes · `?ts` prefix timestamps. A bare repo name assumes owner `kradalby`; `owner/repo` is explicit. Commit hashes must be the full 40 characters — garnix rejects abbreviated ones, which is why the repo listing prints them in full. Private repos work: the service holds the token, so the tailnet ACL is the only access control.

Only if garnixlogs itself is down, go to the API directly — and note that `$GARNIX_TOKEN` is not a Bearer token. It is the Basic-auth password for `POST /api/auth/jwt`, which mints the 1h JWT every other endpoint wants. Sent as a Bearer token it does not fail; it reads as anonymous, which answers on public repos and returns a misleading "not found" on private ones. Check `/api/whoami` before believing a 404.

## Commits & PRs

Log style: `component: imperative summary` (`meta: move versions into one file`, `nix: flake update`). Squash fixups locally; body only when context is needed. PRs list the validation commands run and call out changed secrets or keys.

## Secrets

Never commit plaintext. Edit `secrets/*.age` with `ragenix --rules secrets/secrets.nix -e secrets/<name>.age` (works from repo root) so recipients in `secrets/secrets.nix` stay authoritative. Collect new host keys with `ssh-keyscan -t ed25519 <host>` before adding them as recipients. New services declare their secret inputs in the target host's module. `.env` is for short-lived experiments only; persistent values belong in agenix.
