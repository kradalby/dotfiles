# Web / Frontend

## Default: server-rendered Go

- `kra/web` for the HTTP + Tailscale server (muxes, `/metrics`, `/debug`, graceful shutdown).
- **`elem-go` for all HTML** — typed builders, never string templates.
- **htmx** for interactivity (`hx-post`, `hx-target`); **SSE** for live updates (mirror eventbus payloads to `/events`).
- Inline `<style>`, system fonts, accessible colors, responsive grids. No SPA framework unless genuinely required.
- Standard endpoints: `/metrics`, `/health`, `/debug/*`, plus domain routes (`/toggle`, `/api/...`).

## Frontend-via-nix (preferred)

Build elm/parcel/tailwind _inside_ the derivation — reproducible, no ad-hoc `npm run`:

- Node deps pinned: `fetchYarnDeps` / `npmDepsHash`. Elm deps: `fetchElmDeps` + `elm-srcs.nix`.
- Tailwind/parcel compile runs in `buildPhase`/`patchPhase`; output embedded into the Go binary via `//go:embed dist/*`.
- hugin pattern: `huginDeps` (yarn2nix) → `huginElm` (parcel build → `$out/dist`) → `hugin` (buildGoModule embeds dist).

## Copy from

- `hugin/flake.nix` — Elm/parcel/tailwind built in nix, embedded into Go
- `nefit-homekit/web/server.go`, `tasmota-homekit/web.go` — elem-go + htmx + SSE dashboards

## Stay current

- htmx and elem-go releases; new attributes/builders before hand-rolling.
- Check `kra/web` for new server helpers.
