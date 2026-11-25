Disk full? Run `disk-cleanup -y` (see `--help`). It frees `/tmp` and `/`, cheapest loss first, and stops once `/` is below its limit. Exit 3 means the rest needs a person, so ask.

`/tmp` is a separate tmpfs, so nix and docker cleanup never frees it. Still blocked on `/tmp`: `mkdir -p ~/.cache/tmp/<name> && TMPDIR=~/.cache/tmp/<name> <cmd>`.

`[DIRTY]` trees hold unsaved work: ask before removing them.

Scratch under `~/.cache` or `~/*tmp*` can be removed once idle for a week. Keep results you need elsewhere.
