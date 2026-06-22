# Python

- **Type everything.** Full annotations on every def, arg, and return; treat missing/`Any` types as errors. Enforce in CI, not just locally.
- **`pyright` strict** (`typeCheckingMode = "strict"`) — fail the build on type errors.
- **`ruff`** for lint _and_ format, with the annotation/modernize rule sets on (`ANN`, `UP`, `SIM`, `B`, `I`); no separate isort/black.
- **`uv`** for environments + packages (not poetry/pip).
- Target the latest Python (3.12+), line length 100.
- Nix flake provides the toolchain; `.venv` via `shellHook` + `uv sync`.

## Copy from

- `betteroako` — uv + ruff + pyright strict, nix devShell

## Stay current

- Latest CPython (use newest stable); adopt new typing syntax.
- ruff & pyright releases — new lint rules and stricter type checks to enable.
- `uv` releases for workflow changes.
