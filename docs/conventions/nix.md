# Nix

## flake-checks (the rule)

All checks route through [`kradalby/flake-checks`](https://github.com/kradalby/flake-checks). Extend it; don't hand-roll checks. CI just calls the resulting `checks.*`.

```nix
inputs.flake-checks.url = "github:kradalby/flake-checks";
inputs.flake-checks.inputs.nixpkgs.follows = "nixpkgs";   # share cache
# ...
let
  fc = flake-checks.lib;
  common = {
    inherit pkgs;
    root = ./.;
    pname = "myapp";
    version = "0.1.0";
    vendorHash = "sha256-…";
    goPkg = pkgs.go_1_26;                                  # pin latest Go
  };
in {
  packages.default = fc.goBuild common;
  formatter        = fc.formatter common;
  checks = {
    build         = fc.goBuild common;
    gotest        = fc.goTest common;
    golangci-lint = fc.goLint common;
    formatting    = fc.goFormat common;                    # gofumpt + goimports + nixpkgs-fmt
  };
}
```

- Each check's src is fileset-filtered → unrelated edits hit cache.
- `goTest` opts: `goRace`, `goSkip`, `goTags`, `testEnv`, `testPackages`, `proxyVendor`.

## Structure

- `flake-utils.lib.eachDefaultSystem`; dependent inputs always `follows = "nixpkgs"`.
- Name the numtide input `flake-utils` — always, every repo. Match upstream's name so overrides line up; never alias it to `utils`.
- Override a dep by its **real** input name: `inputs.foo.inputs.flake-utils.follows = "…"`. A wrong name silently warns `override for a non-existent input` and the dedup never happens. (headscale, homewizard-p1-exporter)
- Expose `overlays.default`, and for services `nixosModules.default`.
- Flake apps for ergonomics: `nix run .#test` / `.#test-race` / `.#lint` / `.#coverage`. (z2m-homekit)

## vendorHash churn → flakehashes.json

Hashes that change often live in a root `flakehashes.json`, read with
`builtins.fromJSON (builtins.readFile ./flakehashes.json)` (e.g. `.vendor.sri`). A small
`cmd/vendorhash` Go tool (`check` / `update`) keeps it in sync with `go.mod`/`go.sum`; prek
runs `go run ./cmd/vendorhash check`. Decouples noisy hashes from `flake.nix`. (tsnixcache, headscale, sfiber)

`common` extras seen alongside the required keys: `subPackages`, `env = { CGO_ENABLED = "0"; }`,
and `.overrideAttrs` to attach `meta` (description/homepage/license/mainProgram). (tsnixcache)

## NixOS module

- Options: `services.<name>.{enable,package,user,group,dataDir,environmentFile,environment}`.
- `config = lib.mkIf cfg.enable { … }`; systemd hardening (DynamicUser, Restart, WorkingDirectory).
- Generate config files with `pkgs.formats.{yaml,toml}`. Secrets via `environmentFile` / `LoadCredential` (→ [secrets.md](secrets.md)).
- Split server/client concerns into separate modules; export each + a `default`. (tsnixcache: `module-server.nix` + `module-client.nix`)
- **Test modules in CI**: a `nix eval` smoke test (z2m-homekit) or full NixOS VM tests in `nix/tests/*.nix` wired as `checks` (tsnixcache).

## Graceful shutdown (always prefer over forced)

Design services to stop **gracefully**; never rely on SIGKILL. The app gets
SIGTERM (systemd `KillSignal=SIGTERM`, launchd's default unload) plus a generous
`TimeoutStopSec` to flush state. For `claude remote-control` this is load-bearing:
a clean SIGTERM lets it *preserve* its environment, so a restart resumes the same
builder instead of orphaning a fresh one (forced kills filled the claude.ai picker
with dead duplicates and lost in-flight sessions).

- `KillMode=mixed` over `control-group`: SIGTERM hits the main pid so it
  orchestrates its own teardown; SIGKILL only mops up stragglers at timeout.
- Watchdog / restart paths restart gracefully first (`systemctl restart`,
  `launchctl kill SIGTERM` + `KeepAlive`), escalating to a forced kill
  (`kickstart -k`, SIGKILL) only after a grace window so a wedged process still
  recovers. Never reach for `kickstart -k` as the default. (claude-code module)

## devShell

`go_<ver>`, `gopls`, `golangci-lint`, `gofumpt`, `prek`, `gnumake`. `shellHook` may set `CGO_ENABLED=0` for static builds.

## Formatter

`treefmt` (`treefmt.toml`) orchestrates gofumpt + goimports + nixpkgs-fmt; exposed as `formatter = fc.formatter common`. `alejandra` in dotfiles. Pick one nix formatter per repo, stay consistent.

## Containers (when needed)

Prefer nix-built images (`dockerTools.buildLayeredImage`); fall back to a multi-stage `Dockerfile` only when nix can't. Prefer shipping a NixOS module over a container for your own services.

## Copy from

- `tsnixcache` `flake.nix` + `nix/module-{server,client}.nix` + `nix/tests/*.nix` — freshest full example
- `z2m-homekit/flake.nix` + `z2m-homekit/nix/module.nix` — modern flake + module + CI
- `kra/flake.nix` — minimal flake-checks wiring
- `headscale/flake.nix` — full (overlay, module, flakehashes, docker)

## Stay current

Before building, verify against upstream — don't assume this guide is current:

- nixpkgs manual + recent nixpkgs commits/PRs for changed packaging & module conventions (`buildGoModule`, formatters, `lib`).
- Search `lib` with **noogle** (`noogle.dev`) before writing a helper.
- Check `flake-checks` for new check helpers; cross-check the freshest repo (`tsnixcache`, `wc3ts`).
- Mirror current NixOS option conventions from `nixos/modules` in nixpkgs for the service category you're building.
