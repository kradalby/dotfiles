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
- **Pi:** the [`raggi/aperture-models`](https://github.com/raggi/aperture-models)
  extension (flake input `pi-aperture-models`) registers one provider per
  Aperture backing route. Use `/reload` or reopen `/model` to refresh.
- **Codex** and **Claude** use fixed models with built-in metadata.

`opencode.json`, `~/.hermes/config.yaml` and `~/.pi/agent/settings.json` are
`my.mutableJson` entries: seeded once, then owned by the agent. Compare or
adopt the Nix version with `<name>-diff` / `<name>-reset` (`opencode`,
`hermes`, `pi-settings`).

## Verify

```console
curl -fsS http://ai.corp.ts.net/v1/models | jq -r '.data[] | [.id, (.supported_endpoints | join(","))] | @tsv'
opencode models | grep aperture
hermes doctor
pi --list-models
herdr integration status
```

## Rex

`services.rex` runs one server as a systemd user service. Both networks reach
the same sessions:

- Personal tailnet, through Rex's own `tag:rex` node:
  `rex -S kradalby-llm-rex.dalby.ts.net`
- Work tailnet, through this VM's tailscaled: `rex -S kradalby-llm:7297`. Only
  the node's owner is admitted.

On first start, open the link from `rex server status` and sign in as
`kradalby@kradalby.no`.

A Home Manager switch does not restart the server. Running the new version
needs `systemctl --user restart rex`, which ends every program.

After a restart or a crash, sessions, windows, blocks and working directories
come back as new shells. A crash can lose the newest working directories.
Commands do not run again, and scrollback and environment variables are gone.
Resume agents with their own command, such as `claude --resume`. Keep long
output in a file.

When memory runs out, the kernel should pick programs in blocks before the
server, because fish raises their OOM score. `rex run --shell=none` skips fish,
so those programs keep the server's score. A killed program leaves the server
and the other blocks running.

Programs under `sudo` read root's terminal database, which Home Manager cannot
change here. Add Rex's entry once:

```console
sudo ~/.nix-profile/bin/rex terminfo setup --system
```

Rex refuses to start if this VM's own node gets tagged, because owner-only
admission then admits nobody. That also takes down the personal route.

There is no Prometheus probe. This VM has no node_exporter, and a `tag:monitoring`
grant to `tag:rex` would let core.oracldn run programs as `ubuntu`.

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
2. Set `defaultModel` in `default.nix`. For Pi, also check that
   `defaultProvider` names a backing route serving it
   (`.metadata.provider.id`).
3. When updating the `hermes-agent` flake input, compare `_config_version` with
   `hermes_cli/config_defaults.py` in the new locked revision.
4. Run `nix fmt`, switch Home Manager, then `opencode-reset`, `hermes-reset` and
   `pi-settings-reset`: seeded files never pick up Nix changes on their own.
