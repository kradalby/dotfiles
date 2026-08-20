# Secrets

## Dev: .envrc + setec (or 1Password)

- direnv with `use flake` (no `--impure` unless required).
- Pull secrets on shell entry — never commit them. Preferred: `secret_env`
  (setec via the `secret` CLI, backed by ts1p), which is what this repo's own
  `.envrc` uses:

```bash
use flake
secret_env -v <<'SECRETS'
  GARNIX_TOKEN   garnix/api/token
  GARNIX_SERVER  garnix/api/server
SECRETS
```

- `op read` works the same way for values that only live in 1Password:

```bash
export GIGAHOST_TOKEN=$(op read "op://Private/gigahost/token")
export TF_VAR_unifi_password=$(op read "op://Private/unifi.ldn/password")
```

- Terraform vars use the `TF_VAR_*` prefix (→ [terraform.md](terraform.md)).
- Non-secret dev config (URLs, ports, debug flags) inline in `.envrc`.
- `.envrc.local` (gitignored) for per-machine overrides, sourced if present.

## Prod / NixOS: ragenix

- **ragenix** (`age`) for all NixOS secrets — not sops.
- `secrets/secrets.nix` maps user + host public keys to which `.age` files they may decrypt.
- Encrypted `secrets/*.age` are committed (ciphertext only).
- Declare and consume in a module:

```nix
age.secrets.cloudflare-ddns-token = {
  file  = ../secrets/cloudflare-ddns-token.age;
  mode  = "0400";
  owner = "cloudflare-ddns";
};
# then either:
systemd.services.cloudflare-ddns.environment.CLOUDFLARE_API_TOKEN_FILE =
  config.age.secrets.cloudflare-ddns-token.path;
# or, for key=value env files:
serviceConfig.EnvironmentFile = config.age.secrets.litestream.path;
```

## Tailscale keys

Pre-auth keys are **single-use**, never reusable. A committed `.age` is
therefore normally a spent key; mint a fresh one just before a join/rebuild.
An already-joined node ignores its auth key (tailscaled only reads it on
`NeedsLogin`; tsnet ignores it once its state dir holds a node key), so
rotating or re-scoping a key is a **noop until the next bootstrap/rebuild**.

- **Host join** — `common/tskey.nix` (`tailscale-preauthkey.age`), root-only
  (default `0400`, never a `mode` override). Mint with `authkey kradalby`
  (single-use by default); `-rotate -commit` writes it back and commits.
- **Per service** — each tsnet app / proxy gets its **own** key: a scoped
  `age.secrets.<svc>-tskey` with `owner = <service user>` (or read via systemd
  `LoadCredential` so the file stays `0400` root), recipients limited to the
  owning host, so a leak is bounded to one service on one host. Mint these as
  tagged `tailscale_tailnet_key` resources in `infrastructure/tailscale/`
  (`reusable = false`, `tags = ["tag:<app>"]`), copy the sensitive output into
  the `.age`. The app tag applies on the node's next rebuild.
- Never share the host key across services, and never widen `mode` past `0400`.

## Copy from

- `infrastructure/.envrc` — 1Password + TF_VAR + TF_ENCRYPTION
- `dotfiles/secrets/secrets.nix` — key map
- `dotfiles/common/litestream.nix` (environmentFile) / `common/ddns.nix` (path) — consumption patterns
- `dotfiles/machines/core.oracldn/golink.nix` / `webpage.nix` — per-service Tailscale key (`owner` + scoped recipients)
