# Secrets

## Dev: .envrc + 1Password

- direnv with `use flake` (no `--impure` unless required).
- Pull secrets on shell entry from 1Password — never commit them:

```bash
use flake
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

## Copy from

- `infrastructure/.envrc` — 1Password + TF_VAR + TF_ENCRYPTION
- `dotfiles/secrets/secrets.nix` — key map
- `dotfiles/common/litestream.nix` (environmentFile) / `common/ddns.nix` (path) — consumption patterns
