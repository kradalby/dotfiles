# Go

## Version & syntax

- Pin the **latest** Go in `go.mod` and the flake (`go 1.26`, `pkgs.go_1_26`). Match across build/lint/test.
- Use current-Go features: generics, range-over-func / iterators (`iter.Seq`), `slices`/`maps`/`cmp` stdlib, `min`/`max`. Don't hand-roll what the stdlib gives you.

## Layout

- Packages at repo root, named by function (`state/`, `db/`, `web/`, `config/`, `mapper/`).
- **Never `internal/`, `pkg/`, `pkgs/`** or generic container dirs (generated code excepted). (headscale)
- `main` packages under `cmd/<name>/`, thin → one `Run()`/`Execute()`; logic lives in packages. (headscale, kra)
- Generated code in `gen/`, marked `// Code generated …`, lint-excluded.
- Every app serves on **both** a tsnet listener and a local listener, unless explicitly opted out.

## Dependencies

stdlib → `tailscale.com/*` → `kra/*` → blessed dep (below) → your own. Stop at the first that works.

| Need                                       | Use                                                                                                                      |
| ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------ |
| Networking / mesh / debug                  | `tailscale.com/*` — tsnet, tsweb, envknob, net/netip, util/eventbus                                                      |
| Shared HTTP+Tailscale server, HTML helpers | `kra/web`, `kra/html`                                                                                                    |
| Logging                                    | `log/slog` (zerolog only in headscale — tailscale heritage)                                                              |
| Config                                     | `github.com/knadh/koanf/v2` (env-only light; add `file` provider when a config file exists). `Netflix/go-env` is legacy. |
| CLI / flags                                | `github.com/peterbourgon/ff/v4` (the `ff.Command` tree) — **never cobra**. Prefer v4; `ff/v3/ffcli` is the older pattern, migrate when touched. |
| Internal decoupling                        | `tailscale.com/util/eventbus`                                                                                            |
| All HTML                                   | `github.com/chasefleming/elem-go` + htmx + SSE (server-rendered, no SPA)                                                 |
| Tests                                      | `testify/require` + `google/go-cmp`                                                                                      |
| Metrics                                    | `prometheus/client_golang` (exposition → Debug & metrics)                                                                |
| Backoff (never `time.Sleep`)               | `cenkalti/backoff/v5`                                                                                                    |

Specifics:

- **ff/v4:** root `*ff.Command` + `Subcommands`, each a `newXxxCmd()` owning its `ff.FlagSet`; `cmd.ParseAndRun(ctx, os.Args[1:])`; `signal.NotifyContext` for shutdown. (gigahost-go — v4 reference). `ff/v3/ffcli` (`*ffcli.Command` + stdlib `flag.FlagSet`) is the older form still in tsnixcache.
- **koanf:** env-only by default (light config, no file needed); add the `file` provider only when a config file exists. `Netflix/go-env` is legacy — don't use for new code.
- **elem-go** for every HTML surface, never string templates.
- **slog** constructed once, passed via constructor; no `fmt.Println`, no `log.Fatal`.
- `net/netip` not `net.IP`; `envknob` for toggles; `errgroup` + `context` threaded top-down (no bare `go`).
- **Twelve-factor:** config from env, log to stdout, stateless where possible.

## Debug & metrics

- **Internal apps** (personal use): build on `kra/web`. It wraps tsnet + a local loopback listener and mounts `tsweb.Debugger` on both — one gated `/debug/` surface: varz, expvar (`/debug/vars`), pprof, `/debug/gc`, statsviz — plus `/metrics` (promhttp) linked from `/debug`. All gated to tailnet peers + loopback. Free; don't hand-roll.
- **Open-source / standalone apps** that can't depend on `kra` (ts1p, headscale): wire `tsweb.Debugger(mux)` yourself — on the local listener always, on tsnet when present — register statsviz, expose `/metrics` (promhttp), and link it from the `/debug` index (`debugHandler.URL("/metrics", "Metrics (Prometheus)")`). Import `_ "tailscale.com/tsweb/promvarz"` so `/debug/varz` carries the Prometheus registry too.
- Never a bare `/metrics` on an ad-hoc port with no `/debug`. Prometheus scrapes `/metrics`; access is `tsweb.AllowDebugAccess` (tailnet peers + loopback), no separate auth.

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
- `tsnixcache` — freshest full repo: ff/v3 ffcli subcommands, slog, package layout, bench tests
- `gigahost-go` — **ff/v4** (`ff.Command` tree) + koanf config, Option pattern (`client/options.go`)
- `headscale/.golangci.yaml` — enable-all / disable-few lint config
- `kra/web` — tsnet + local listener, `tsweb.Debugger` on both, statsviz, `/metrics`

## Stay current

Before building, verify against upstream — don't assume this guide is current:

- Latest Go release + notes (`go.dev/doc/devel/release`, `go.dev/blog`); bump `go.mod`, adopt new stdlib/syntax.
- Check `golang.org/x/*` and `tailscale.com/*` for a helper before hand-rolling.
- Search proposals/issues (`github.com/golang/go`) and `r/golang` / golang-nuts for anything non-trivial you'd write custom.
