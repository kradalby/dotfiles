---
description: Update all nix and flake dependencies
---

update all pinned dependencies

1. survey: `GITHUB_TOKEN=$(gh auth token) tack look -v` (tack repos, `.tack/`
   present) or `nix flake update --dry-run`-style diff of `flake.lock`
2. changelogs: for every pin that moves, spawn cheap agents (haiku), a few
   pins each, in parallel. Each reads the release notes or commit log between
   the locked and the new rev and reports: breaking changes, renamed options,
   needed config edits, Go/Rust toolchain floor. Summarise before updating.
3. update: `tack update` (or `nix flake update`); `tack undo` reverts
4. fix what breaks, shortest path first:
   - a moved Go source fails with the new `vendorHash`: copy it in
   - a release needing a newer toolchain than the fleet's: build that one
     package with the newer one (e.g. nixpkgs-master's go), never hold the pin
5. `nix flake check`; fix deprecations it reports
6. bump versioned builders (e.g. `pkgs.buildGo127Module`) to the newest
