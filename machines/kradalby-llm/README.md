# kradalby-llm agent configuration

Every agent on this host reaches models through Aperture at
`http://ai.corp.ts.net` and its MCP server at `http://ai.corp.ts.net/v1/mcp`.
Aperture's per-user model list, `/v1/models` (its `/api/` is admin-only), is
the only catalog. Nix pins policy and the default model (`defaultModel` in
`default.nix`); each agent discovers the models at runtime:

- **OpenCode:** `pkgs/scripts/opencode-aperture-models.js` adds the
  `aperture-openai-compatible` provider with every model that advertises
  `/v1/chat/completions`, limits included. It caches the last good list in
  `~/.cache/opencode-aperture/` and fetches once per process, so restart
  OpenCode to see new models.
- **Hermes:** the `custom:aperture-completions` provider has no `models:` list;
  Hermes discovers them from `/v1/models` itself.
- **Codex** and **Claude** use fixed models with built-in metadata.

`opencode.json` and `~/.hermes/config.yaml` are `my.mutableJson` entries:
seeded once, then owned by the agent. Compare or adopt the Nix version with
`opencode-diff` / `opencode-reset` and `hermes-diff` / `hermes-reset`.

## Verify

```console
curl -fsS http://ai.corp.ts.net/v1/models | jq -r '.data[] | [.id, (.supported_endpoints | join(","))] | @tsv'
opencode models | grep aperture
hermes doctor
herdr integration status
```

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

1. Confirm the exact ID in `/v1/models` and that it advertises
   `/v1/chat/completions`.
2. Set `defaultModel` in `default.nix`.
3. When updating the `hermes-agent` flake input, compare `_config_version` with
   `hermes_cli/config_defaults.py` in the new locked revision.
4. Run `nix fmt`, switch Home Manager, then `opencode-reset` and
   `hermes-reset`: seeded files never pick up Nix changes on their own.
