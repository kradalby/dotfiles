# kradalby-llm agent configuration

This Home Manager target gets its remote model catalogs and Aperture MCP
configuration from `http://ai.corp.ts.net/api/agent-config`. The activation
merges that generated data with the local policy in `default.nix` and owns:

- `~/.config/opencode/opencode.json`
- `~/.hermes/config.yaml`

Do not edit those files directly. The next successful refresh replaces them.
OpenCode's Ollama provider, its frontier agents, and Hermes' `frontier` MoA
preset are Nix-defined overlays and survive catalog refreshes.
Both tools start with their frontier mixture selected by default.
Hermes' Herdr plugin enablement is also part of the overlay; Herdr owns the
plugin files and activation reinstalls them after each refresh.

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
curl -fsS http://ai.corp.ts.net/api/agent-config | jq '.models'
curl -fsS http://ai.corp.ts.net/api/agent-config | jq -r '.configs.opencode' | jq
curl -fsS http://ai.corp.ts.net/api/agent-config | jq -r '.configs.hermes'
opencode debug config
hermes doctor
hermes moa list
herdr integration status
```

Both generated configs must contain the MCP endpoint advertised in the API's
`.mcpEndpoint`: OpenCode at `mcp.aperture`, and Hermes at
`mcp_servers.aperture`.

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

## Updating the frontier mixture

When Aperture adds or retires a model:

1. Inspect `.configs.opencode` and `.configs.hermes` as shown above. Confirm the
   exact model ID and which provider/transport lists it.
2. Update `opencodeOverlay.agent` and `hermesOverlay.moa.presets.frontier` in
   `default.nix`. OpenCode model names are `<provider>/<model-id>`; Hermes uses
   `custom:<provider>` and a separate model ID.
3. When updating the `hermes-agent` flake input, compare `_config_version` with
   `hermes_cli/config_defaults.py` in the new locked revision and update the
   overlay and validation together.
4. Update the required-model checks in `aperture-agent-config-sync.nix`. These
   intentionally stop a retired or rerouted model from producing a partially
   usable mixture.
5. Run `nix fmt`, build the Home Manager target, activate it, and smoke-test
   every reference model plus the GPT aggregator. Check MCP tool discovery in
   both OpenCode and `hermes doctor`.

The deterministic sync behavior can be checked without contacting Aperture:

```console
nix build .#checks.x86_64-linux.aperture-agent-config-sync
```

The current mixture uses GPT-5.6 Sol as aggregator with Claude Opus 5,
DeepSeek V4 Pro, Gemini 3.7 Flash, Kimi K3, and GLM 5.3 as independent
reviewers. OpenCode orchestrates these through subagents; Hermes exposes the
same lineup as its native `frontier` MoA preset.
