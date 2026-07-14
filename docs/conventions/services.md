# Services

Every service on the fleet answers two questions by construction: **how do I
reach it** (always Tailscale, never a raw WAN/LAN port) and **how do I know it's
alive** (always Prometheus). Each has a ladder — take the highest tier that fits.

Legacy services predate this; bring one up to it when you next touch it.

## Reachability — always Tailscale

1. **Tailscale service (VIP)** — _preferred._ `services.tailscale.services.<name>.endpoints = { "tcp:443" = "http://localhost:<port>"; }`. A named VIP on the home tailnet, HA-capable, no per-host firewall rule. Declare the matching `tailscale_service` in `infrastructure/tailscale` (`services.tf`); `tag:svc` auto-approves the advertisement. (core.tjoda/rest-server.nix, common/minio.nix, monitoring.nix: prom/alertmanager/pushgateway)
2. **Tailscale proxy** — _when the service must live on another tailnet_ (headscale / sandefjordfiber, or bridging tailnets). `services.tailscale-proxies.<name> = { hostname; loginServer; backendPort; tailscaleKeyPath; }` — a dedicated tailscaled that joins that control server and proxies one local port onto it. Heavier (a whole extra daemon); reach for it only cross-tailnet. (modules/tailscale-proxy.nix; core.tjoda/rest-server.nix `restic-sfiber`)
3. **ACL-approved port** — _last resort,_ for raw `host:port` (exporters, backends with no VIP). `networking.firewall.interfaces.tailscale0.allowedTCPPorts = [<port>]` (per-interface — survives a `mkForce`d host firewall) **plus** a grant in `infrastructure/tailscale/policy.hujson`. Both halves are required: without the firewall rule the port silently rides tailscaled's implicit accept, one netfilter-mode change from dark. (garnix/default.nix, ts1p.ldn/default.nix)

Never a public / Funnel surface unless the service is deliberately public.

The tailscale `tailscale_service` objects **and** the ACL policy live in the
separate infrastructure repo, `~/git/infrastructure` (`kradalby/infrastructure`),
not in dotfiles — the dotfiles side only _advertises_ the VIP / opens the port.
→ [terraform.md](terraform.md). **Always pair a `tag:svc` (or a specific tag)
with an ACL grant scoped to the narrowest src → dst → ports** that works; a VIP
with no grant is unreachable, and a broad grant defeats the point. Give a
distinct service its own VIP (self-documenting scrape + grant) rather than
piggybacking a second port on an unrelated one.

## Observability — always Prometheus

A service nothing watches fails CI (`checks.monitoring-coverage`). Take the highest tier that fits; **always at least the minimum.**

1. **Preferred: native metrics + app-level alerts.** Expose `/metrics` (→ [go.md](go.md) for the app side: `tsweb.Debugger` + promhttp). Add a scrape job (`scrapeJob` / `exporterJob` in monitoring.nix) and alert on **real** metrics:
   - **Verify every metric name against source before writing an alert** — grep the pinned `/metrics` or the code. A typo'd or renamed metric matches zero series and pages nobody (the `litestream_replica_lag_seconds` class).
   - **Rate-shaped** (errors/sec, latency) → a sloth SLO in `slo-spec.nix`. **State-shaped** (disk, cert expiry, up/down, queue depth) → a plain threshold rule.
   - Back a critical metric with an **`absent()` canary** so a rename pages instead of silently going green.
2. **Minimum: is it healthy.** A black-box probe — `probe_success{job="…"} == 0`. Every service gets one _even with_ native metrics: internal metrics tell you _how_ it's failing, only a probe tells you _that_ it works.

Fleet rules: one Discord sink; the external dead-man (healthchecks.io) is the only thing that fires when the pipeline itself dies. A new exporter or host with no scrape fails `checks.monitoring-coverage` until it is wired up or allowlisted with a reason. Every rule carries a promtool unit test in `checks/prometheus-rules` — an alert with no test is not done.

**Physical disks get SMART.** Every bare-metal host runs `monitoring.smartctl` over all disks by stable `/dev/disk/by-id` (`SmartctlDiskMissing` pins the count). VMs have no real SMART. Immutable hosts that hide SMART behind a vendor API instead of an exporter get bridged to a textfile — e.g. IncusOS serves per-drive SMART as JSON at `GET :8443/os/1.0/system/storage`, not on `/metrics` (core.ldn bridge: TODO).

### Metrics transport — textfile first, pushgateway only when unavoidable

- **textfile** (`node_exporter --collector.textfile`) — the default when a job runs _on_ a scraped host (sanoid snapshot age, the litestream restore-test, local timers). Rides the host's existing node scrape, no extra service or ACL. Write atomically (`.tmp` → `mv`). Caveat: the file persists if the writer dies, so alert on the metric's own timestamp, not the file's existence.
- **pushgateway** — only for producers Prometheus can't reach: off-fleet laptops (rustic), foreign-tailnet proxies (sfiber), truly ephemeral jobs. Costs that keep it a last resort: pushed metrics persist forever until deleted (silent staleness → you _must_ alert on `push_time_seconds`), there is no per-target `up`, it needs `honor_labels`, and it's a shared SPOF. Don't reach for it just because it's easy.

## Backups

Every backup mechanism must prove the data _arrived_, not just that a timer ran. A backup you have never restored is not proven.

- **restic** — files on disk (datadirs, `/var/lib/*`) and swept-in dumps (postgres et al.). Prove success: an `ExecStopPost` drop-in pushes `restic_backup_last_success_timestamp_seconds`, alerted on staleness; the REST server's `rest_server_blob_write` is a repo-side cross-check; `restic check` runs (read-data locally, metadata-only for egress repos like Jotta). For dumps, alert on _both_ the dump timer freshness (`PostgresqlBackupStale`) and that restic captured it. **TODO: add a restore check** — restore a snapshot + verify — like litestream's.
- **litestream** — live sqlite. Off-site replica, sync-error SLO + `absent()` canary, and a **weekly restore-test that restores from the replica, integrity-checks, and stamps `litestream_restore_test_last_success_seconds` into the textfile collector** (`LitestreamRestoreStale` alerts on it). This is the restore-check pattern to copy. (common/litestream.nix)
- **rustic** — macOS laptops; off-fleet, so via pushgateway.

**Restore checks are the gold standard:** every mechanism should grow one — restore, verify, emit `*_restore_test_last_success_seconds`, alert on staleness — and be **verified** to actually fail when the backup is bad.

## Copy from

- Tailscale VIP service: `machines/core.tjoda/rest-server.nix`, `common/minio.nix`
- Tailscale proxy (cross-tailnet): `modules/tailscale-proxy.nix`, `machines/core.tjoda/rest-server.nix` (`restic-sfiber`)
- ACL port + firewall: `machines/garnix/default.nix` + `infrastructure/tailscale/policy.hujson`
- Monitoring wiring: `machines/core.oracldn/monitoring.nix` (helpers + alerts), `…/slo-spec.nix` (SLOs), `checks/{prometheus-rules,monitoring-coverage}`

## Stay current

- Mirror current NixOS `services.tailscale` options — VIP `services` support is evolving upstream.
- The tailnet policy (`infrastructure/tailscale`) is the other half of every non-VIP surface; check the grant before assuming a port is reachable.
- Before writing an alert, re-grep the metric name against the _deployed_ version; exporters rename series across releases.
