# AGENTS NOTES – `home.ldn`

- This VM imports both HomeKit services; keep `./nefit-homekit.nix` and `./tasmota-homekit.nix` wired in under `machines/home.ldn/default.nix`.
- Secrets: `age.secrets.nefit-homekit-env`, `age.secrets.tasmota-homekit-env`, and `age.secrets.tailscale-preauthkey` must be present before `nixos-rebuild`. They are owned by the respective service users.
- `services.nefit-homekit` uses `/var/lib/nefit-homekit` as `storagePath` and reads `/etc/nefit-homekit/env`. Keep those paths when rotating secrets so the state survives rebuilds.
- `services.tasmota-homekit` expects `/etc/tasmota-homekit/plugs.hujson`; edit `machines/home.ldn/tasmota-homekit.nix` when the plug list changes so git tracks it. The service reads its env vars from the agenix secret.
- Both services use the shared Tailscale pre-auth key secret. Regenerate it via `common/tskey.nix` before it expires, otherwise the kra listeners will fail to join the tailnet.
- Run `nixos-rebuild test --flake .#home.ldn` after touching either module so the host picks up the updated options.

## Nix Package Creation

- Use `nix-init` to generate nix packages from URLs (e.g., GitHub releases, crates.io)
- Use `nurl` to fetch and generate nix expressions for package sources

## Code Formatting

Always use the appropriate formatters before committing code:

- **Nix**: `alejandra` (available in pkgs/home-packages.nix)
- **Go**: `gofumpt` (available in pkgs/home-packages.nix)
- **Python**: `black` and `isort` (available in pkgs/home-packages.nix)
- **JavaScript/TypeScript**: `prettier` (available in pkgs/home-packages.nix)
- **Shell**: `shfmt` and `shellharden` (available in pkgs/home-packages.nix)
- **YAML**: `yamllint` (available in pkgs/home-packages.nix)
- **Other**: Refer to `pkgs/home-packages.nix` for language-specific formatters
