# Swift

_Small sample (munin, SwiftExif, Logger.swift) — lower confidence than Go/Nix._

- **SwiftPM only** (`Package.swift`, pinned `swift-tools-version`); one public product per package. Minimal deps.
- **Swift is kept OUT of the flake** — nixpkgs lags upstream Swift. The flake ships only C deps (libvips, libexif, …) + tools; install Swift via swiftly or a toolchain tarball.
- Format + lint: swift-format + swiftlint, driven by a `Makefile` (`make fmt` / `make lint`). No `.swiftformat`/`.swiftlint` in small libs.
- Tests: **swift-testing** (`@Test`/`@Suite`) for new code; legacy XCTest only in older repos.
- Style: `public` explicit on API; value types (`struct`/`enum`) + extensions over class hierarchies; `Sendable`/`Equatable` on public types; `@available(*, deprecated, message:)` for migrations.
- Errors: throwing functions with a typed `enum` error (Sendable, Equatable).
- CI: Swift container (linux) + macOS matrix; `swift build && swift test`. (munin also has a legacy Drone pipeline.)

## Copy from

- `munin` — app: Makefile, swiftlint + swift-format, C-deps-only flake, CI matrix
- `SwiftExif/Sources/SwiftExif/Types.swift` — public struct/enum style, Sendable, doc comments

## Stay current

- Latest Swift release + SwiftPM changes (manifest API, swift-testing).
- swift-format / swiftlint releases for new rules.
