# Repository Guidelines

## Project Structure & Module Organization
The flake root (`flake.nix` plus helpers in `lib/box.nix`) stitches together the major layouts:
- `common/`: shared NixOS/darwin modules, reusable service fragments, or opinionated defaults that multiple hosts import.
- `modules/`: bespoke modules packaged like upstream Nix modules (e.g., `restic.nix`, `tailscale-services.nix`) and consumed by hosts or shared configs.
- `machines/<hostname>/`: full host manifests plus any host-only helper files (systemd units, launchd definitions, secret glue). Keep per-host docs in-line here to limit blast radius.
- `pkgs/`: overlays, derivations, and helper scripts (`overlays/`, `home-packages.nix`, `scripts/`) that extend upstream nixpkgs.
- `home/` and `rc/`: user-mode dotfiles and Home Manager modules; they feed into macOS and Linux hosts alike.
- `bin/`: scripts that Home Manager links into `$PATH`.
- `metadata/`: small, curated datasets (versions, pinning info).
- `secrets/`: agenix payloads plus `secrets/secrets.nix` for key distribution; never drop plaintext into the repo.
Maintaining these boundaries keeps it obvious whether a change affects every host or just one machine.

## Build, Test, and Development Commands
- `direnv allow` or `nix develop` loads the flake dev shell with the formatters and helper CLIs declared in `pkgs/home-packages.nix`.
- `nix flake check` evaluates Linux (`nixosConfigurations`), macOS (`darwinConfigurations`), and packages; run it before pushing.
- `nixos-rebuild test --flake .#<hostname>` applies changes to a NixOS target and `darwin-rebuild switch --flake .#<hostname>` does the same for macOS.
- `nix build .#packages.${system}.<name>` exercises individual packages; scripts under `bin/` should remain runnable once Home Manager syncs.
- Prefer Nix-native helpers when fetching or deploying: `nix-prefetch-git` for pinning sources, `colmena apply` for multi-host rollouts, `nurl <url>` for fetcher snippets, and `nix-init` for scaffolding new derivations.

## Coding Style & Naming Conventions
Install and run `prek` (fast Rust rewrite of pre-commit) so Alejandra enforces Nix formatting every time, alongside `shfmt -i 2 -ci`, `shellcheck`, and Prettier for Markdown. Additional formatters in the dev shell include `golines`/`gofumpt` for Go, `black`/`isort` for Python, `beautysh` for shell, `nodePackages.prettier` for JS/TS, and `yamllint` for YAML. Favor 2-space indentation, descriptive attribute names (`snake_case` in Nix, hyphen-case for scripts), and keep defaults in `common/` while recording host-specific tweaks inside the target `machines/<hostname>/` module. Run `statix` and `deadnix` before large refactors to catch style regressions and unused definitions.

## Testing Guidelines
`nix flake check` is the canonical smoke test; fail fast if a change breaks evaluation on any platform. Follow up with `prek run --all-files` to exercise the YAML/JSON linters, Markdown formatter, and shell analyzers. For service changes or new hosts, run the relevant deploy command (`nixos-rebuild test --flake .#<hostname>` or `darwin-rebuild switch`) and note the outcome in your PR description. Store fixtures, helper scripts, and ad-hoc agent notes beside the module they verify (`modules/restic.nix` <-> `machines/<hostname>/restic.nix`) to keep `name-tests-test` happy.

## Commit & Pull Request Guidelines
Follow the existing log style of `component: imperative summary` (`meta: move versions into one file`, `nix: flake update`, etc.). Squash fixups locally, write body text only when extra context is needed, and reference any issue or host touched. Every PR should list the validation commands you ran (`flake check`, `nixos-rebuild test .#<hostname>`, etc.), highlight secrets or keys that changed, and attach screenshots/logs for UI-facing adjustments. Draft PRs are encouraged for multi-host migrations so others can parallelize validation.

## Secrets & Configuration Safety
Never commit plaintext credentials; instead edit `secrets/*.age` via `nix run .#ragenix -- -e secrets/<name>.age` so recipients from `secrets/secrets.nix` remain authoritative. Collect new host keys with `ssh-keyscan -t ed25519 <host>` before adding them to `secrets/secrets.nix` or ragenix’ recipients; this keeps age policies in sync with reality. New services must declare their secret inputs in the target host’s module (and document ownership inline), and any shared Tailscale/Restic keys should be rotated before expiry. Treat `.env` only for short-lived experiments—persistent values belong in agenix and must be referenced through the module system.
