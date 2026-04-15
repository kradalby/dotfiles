---
description: Update all Go dependencies
---

update all golang dependencies

- systematically upgrade all dependencies by upgrading them one by one or in logical groups
  - run all go test and go build for every successful upgrade
  - fix any syntax or code changes if anything has been deprecated
  - make sure all golangci-lint pass with changes since main (--new-from-rev=)
- make sure nix build works and nix sha has been updated
- if any `modernc.org/sqlite` exist
  - make sure the `modernc.org/libc` is updated in lockstep
    where the version is set to the same as `modernc.org/sqlite` `go.mod` file.
