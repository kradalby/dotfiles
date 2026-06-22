# Go

## Version & syntax

- Pin the **latest** Go in `go.mod` and the flake (`go 1.26`, `pkgs.go_1_26`). Match across build/lint/test.
- Use current-Go features: generics, range-over-func / iterators (`iter.Seq`), `slices`/`maps`/`cmp` stdlib, `min`/`max`. Don't hand-roll what the stdlib gives you.

## Layout

- Packages at repo root, named by function (`state/`, `db/`, `web/`, `config/`, `mapper/`).
- **Never `internal/`, `pkg/`, `pkgs/`** or generic container dirs (generated code excepted). (headscale)
- `main` packages under `cmd/<name>/`, thin → one `Run()`/`Execute()`; logic lives in packages. (headscale, kra)
- Generated code in `gen/`, marked `// Code generated …`, lint-excluded.

## Dependencies

stdlib → `tailscale.com/*` → `kra/*` → blessed dep (below) → your own. Stop at the first that works.

| Need                                       | Use                                                                                                                      |
| ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------ |
| Networking / mesh / debug                  | `tailscale.com/*` — tsnet, tsweb, envknob, net/netip, util/eventbus                                                      |
| Shared HTTP+Tailscale server, HTML helpers | `kra/web`, `kra/html`                                                                                                    |
| Logging                                    | `log/slog` (zerolog only in headscale — tailscale heritage)                                                              |
| Config                                     | `github.com/knadh/koanf/v2` (env-only light; add `file` provider when a config file exists). `Netflix/go-env` is legacy. |
| CLI / flags                                | `github.com/peterbourgon/ff/v3/ffcli` — **never cobra**                                                                  |
| Internal decoupling                        | `tailscale.com/util/eventbus`                                                                                            |
| All HTML                                   | `github.com/chasefleming/elem-go` + htmx + SSE (server-rendered, no SPA)                                                 |
| Tests                                      | `testify/require` + `google/go-cmp`                                                                                      |
| Metrics                                    | `prometheus/client_golang`                                                                                               |
| Backoff (never `time.Sleep`)               | `cenkalti/backoff/v5`                                                                                                    |

Specifics:

- **ffcli:** root `*ffcli.Command` + `Subcommands`, each a `newXxxCmd()` owning its `flag.FlagSet`; `root.ParseAndRun(ctx, os.Args[1:])`; `signal.NotifyContext` for shutdown. (tsnixcache, gigahost-go)
- **koanf:** env-only by default (light config, no file needed); add the `file` provider only when a config file exists. `Netflix/go-env` is legacy — don't use for new code.
- **elem-go** for every HTML surface, never string templates.
- **slog** constructed once, passed via constructor; no `fmt.Println`, no `log.Fatal`.
- `net/netip` not `net.IP`; `envknob` for toggles; `errgroup` + `context` threaded top-down (no bare `go`).
- **Twelve-factor:** config from env, log to stdout, stateless where possible.

## Errors

- Package-scope sentinels: `var ErrX = errors.New(...)`.
- Wrap once at the source: `fmt.Errorf("doing thing: %w", err)`; callers decide. Test with `errors.Is`/`errors.As`.
- Constructors return `(*T, error)`, never panic. Optional config via `type Option func(*T) error`. (gigahost-go/client/options.go)

## Tests

- Table-driven; `testify/require` (fail-fast), `google/go-cmp` for diffs.
- Async: `require.EventuallyWithT`, never `time.Sleep`. Helpers take `testing.TB`, call `t.Helper()`.
- Test override hooks: `SetXForTesting`. Race detector on by default.
- Benchmarks in `bench_test.go` per package. (tsnixcache)
- Run via flake apps (→ [git.md](git.md)), not bespoke scripts.

## Style / lint

- `golangci-lint` via `.golangci.yaml`: **enable all, disable a few** — copy the disable list from headscale (cyclop, funlen, lll, wsl, varnamelen, wrapcheck, mnd, exhaustruct, …). Don't curate from scratch.
- Formatting via `treefmt.toml`: gofumpt → `goimports -local github.com/kradalby/<repo>` → nixpkgs-fmt. (tsnixcache). Custom forbidigo bans (`time.Sleep`, inline log-field strings).
- Comments **terse, explain why not what**; package doc comment mandatory; short names in tight scopes.

## Copy from

- `headscale/hscontrol/app.go` — layout, errors, constructors, eventbus wiring
- `tsnixcache` — freshest full repo: ffcli subcommands, slog, package layout, bench tests
- `gigahost-go` — ffcli + koanf config, Option pattern (`client/options.go`)
- `headscale/.golangci.yaml` — enable-all / disable-few lint config

## Stay current

Before building, verify against upstream — don't assume this guide is current:

- Latest Go release + notes (`go.dev/doc/devel/release`, `go.dev/blog`); bump `go.mod`, adopt new stdlib/syntax.
- Check `golang.org/x/*` and `tailscale.com/*` for a helper before hand-rolling.
- Search proposals/issues (`github.com/golang/go`) and `r/golang` / golang-nuts for anything non-trivial you'd write custom.
