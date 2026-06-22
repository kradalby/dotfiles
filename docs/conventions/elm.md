# Elm

- Elm **0.19.1**; source in `src/`.
- elm-pages for full-stack/static sites; `elm/browser` for frontend-only widgets.
- Styling: elm-css (`rtfeldman/elm-css`), or elm-tailwind-modules in elm-pages projects. elm-markdown for content.
- Formatting: elm-format via treefmt-nix.
- **Build via nix**, not bare npm: `fetchElmDeps` + a pinned `elm-srcs.nix` registry; node side via `fetchYarnDeps`. (→ [frontend.md](frontend.md))
- **Test for full coverage:** elm-test on logic, lean on the type system + elm-review. Don't skip tests.

## Copy from

- `hugin` — Elm + parcel + Go embed via nix
- `aspargesgaarden-elm` — elm-pages site with image-processing derivations

## Stay current

- elm package registry for current package versions; elm-pages releases.
- Watch for movement in the (slow-moving) Elm ecosystem before adding deps.
