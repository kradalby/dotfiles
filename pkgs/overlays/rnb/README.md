# rnb — remote nix builder selector

Run a nix command against an on-demand remote builder, chosen by short name.
It maps a name to a builder spec, injects it into `NIX_CONFIG`
(`builders = …` + `max-jobs = 0`), and execs the command — so the build runs on
the remote, not locally. Works the same for `nix build`, `colmena`,
`darwin-rebuild`, and `nixos-rebuild`.

Requires the calling user to be a nix `trusted-user` (the daemon only honors
client-supplied `builders`/`max-jobs` from trusted users).

## Usage

```
rnb dev.ldn -- nix build .#foo            # exec, like env
rnb -m dev-ldn -- colmena apply           # merge: remote + local builders
rnb --auto -- darwin-rebuild switch ...   # pick the reachable builder
rnb --print dev.ldn | source              # fish: set NIX_CONFIG persistently
eval "$(rnb --print --posix dev.ldn)"     # bash/sh
rnb --print --clear | source              # reset
```

- Default replaces builders and forces all builds remote (`max-jobs = 0`).
- `-m/--merge` keeps existing builders (e.g. a local rosetta VM) and allows
  local building.
- `--auto` TCP-probes endpoints and picks the fastest reachable one per host
  (LAN over tailnet).

## Config

Reads a builder registry JSON from the first of: `--config`, `$RNB_BUILDERS`,
`$XDG_CONFIG_HOME/rnb/builders.json` (default `~/.config/rnb/builders.json`).

In this repo the file is rendered from `common/rnb-builders.nix` by `home/rnb.nix`.
Each entry uses the same fields as a nix build machine plus `name`, `host`
(groups endpoints for `--auto`), and `hasRosetta`.

## Portability

Self-contained, zero external dependencies. To move to its own repo: relocate
this directory and rename the module path in `go.mod`.
