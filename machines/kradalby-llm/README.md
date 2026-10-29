# kradalby-llm agent configuration

This Home Manager target builds its remote model catalogs from Aperture's
per-user model list, `http://ai.corp.ts.net/v1/models` (Aperture's `/api/` is
admin-only). Both tools get one Chat Completions provider listing every model
that advertises `/v1/chat/completions`: `aperture-openai-compatible` in
OpenCode, `custom:aperture-completions` in Hermes. The MCP server is
`http://ai.corp.ts.net/v1/mcp`. The activation merges that catalog with the
local policy in `default.nix` and owns:

- `~/.config/opencode/opencode.json`
- `~/.hermes/config.yaml`

Do not edit those files directly. The next successful refresh replaces them.
OpenCode's permissions and extra MCP servers, both tools'
default model (`defaultModel`), and Hermes' Herdr plugin enablement are
Nix-defined overlays and survive catalog refreshes. Herdr owns the plugin files
and activation reinstalls them after each refresh.

## Refresh and verify

The normal update boundary is Home Manager activation:

```console
home-manager switch --flake ~/git/dotfiles#ubuntu@kradalby-llm -b backup
```

For an explicit refresh without a rebuild, run:

```console
aperture-agent-config-sync
```

The command validates both generated configs and replaces them together. If
Aperture is unavailable or invalid, it keeps the last-known-good pair. An
initial activation fails when no valid pair exists.

Inspect and verify the installed configuration with:

```console
curl -fsS http://ai.corp.ts.net/v1/models | jq -r '.data[] | [.id, (.supported_endpoints | join(","))] | @tsv'
opencode debug config
hermes doctor
herdr integration status
```

Both generated configs carry the MCP endpoint: OpenCode at `mcp.aperture`, and
Hermes at `mcp_servers.aperture`.

## Shared commands

`rc/claude/commands/*.md` is the canonical source for personal AI workflows.
The shared `home/ai-commands.nix` module exposes the same workflows to
supported harnesses on every machine:

- Claude and OpenCode use the Markdown files directly as `/command`.
- Hermes loads generated Agent Skills from `~/.agents/skills`; invoke them as
  `/command [arguments]`.
- Codex discovers the same Agent Skills; invoke them as `$command [arguments]`
  or select them through `/skills`.

The wrappers preserve `$ARGUMENTS`, `argument-hint`, and Claude/OpenCode shell
interpolation semantics. Add or edit only the files under
`rc/claude/commands/`, then run the normal Home Manager switch.

## Changing the default model

New Aperture models appear on the next refresh with no change here. To start
both tools on a different model:

1. Inspect `/v1/models` as shown above. Confirm the exact model ID and that it
   advertises `/v1/chat/completions`.
2. Set `defaultModel` in `default.nix`. The sync refuses a catalog that does not
   serve it, keeping the last-known-good pair instead.
3. When updating the `hermes-agent` flake input, compare `_config_version` with
   `hermes_cli/config_defaults.py` in the new locked revision and update the
   overlay and the sync test together.
4. Run `nix fmt`, build the Home Manager target, activate it, and smoke-test the
   default model in both tools. Check MCP tool discovery in both OpenCode and
   `hermes doctor`.

The deterministic sync behavior can be checked without contacting Aperture:

```console
nix build .#checks.x86_64-linux.aperture-agent-config-sync
```
