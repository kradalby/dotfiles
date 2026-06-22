# Terraform

**Always OpenTofu (`tofu`), never Terraform.**

- **No secrets in the repo.** Inject from 1Password via `.envrc` as `TF_VAR_*` (→ [secrets.md](secrets.md)). Mark variables `sensitive = true`.
- **Encrypted state.** Set `TF_ENCRYPTION` (env, in `.envrc`) with a `pbkdf2` key whose passphrase comes from `op read`:

```hcl
key_provider "pbkdf2" "key" {
  passphrase = "<from op read>"
}
method "aes_gcm" "default" { keys = key_provider.pbkdf2.key }
state  { method = method.aes_gcm.default }
plan   { method = method.aes_gcm.default }
```

- One file per concern: `devices.tf`, `networks.tf`, `variables.tf`, `outputs.tf`, `settings.tf`.
- Prefer community providers over rolling your own; `tofu fmt` (wired into prek). 2-space indent.

## Copy from

- `infrastructure/.envrc` — `TF_ENCRYPTION` block + `TF_VAR_*` from 1Password
- `infrastructure/tjoda_unifi/` — file-per-concern layout, `sensitive` vars

## Stay current

- Latest OpenTofu release + notes; new state-encryption / language features.
- Provider registry (`search.opentofu.org`) for the current provider + version before pinning.
