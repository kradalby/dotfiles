---
description: Triage homelab alerts and health signals
---

Triage the fleet. Report only what needs a human. Be brief.

## Access

Prometheus/Alertmanager live on `core-oracldn` and are **not** reachable
from laptops or dev boxes — the tailnet ACL denies `tag:monitoring` ports
and the VIP names (`prom`, `alertmanager`) do not resolve off-host. Go via
SSH:

```sh
ssh core-oracldn 'curl -s "localhost:9093/api/v2/alerts?silenced=false&inhibited=false&active=true"'
ssh core-oracldn 'curl -s -G localhost:9090/api/v1/query --data-urlencode query@-' <<< 'up == 0'
```

Feed PromQL on stdin (`query@-`). Inline `--data-urlencode "query=..."`
gets mangled by nested shell quoting over SSH.

## Steps

Run these; stop early only if the alert pipeline itself is dead.

1. **Firing alerts** — `/api/v2/alerts?silenced=false&inhibited=false&active=true`.
   Group by severity. `Watchdog` must be present; its absence means the
   dead-man is broken.
2. **Silences** — `/api/v2/silences`. Flag any that expire far out or read
   like a forgotten mute. A silence is a deferred decision, not a fix.
3. **Inhibited** — `/api/v2/alerts?inhibited=true...`. Count only. A large
   number under one host-down alert is inhibition working, not a problem.
4. **Down targets** — `up == 0`. Cross-check each host against
   `tailscale status` for last-seen; a host offline for weeks is a
   different story from one offline for minutes.
5. **Pipeline health** — all four must be empty:
   `increase(alertmanager_notifications_failed_total[1h]) > 0`,
   `increase(prometheus_notifications_errors_total[1h]) > 0`,
   `increase(prometheus_rule_evaluation_failures_total[1h]) > 0`,
   `/api/v1/rules` with any rule `health != "ok"`.
6. **Backups** — `(time() - restic_backup_last_success_timestamp_seconds)/3600`.
   Every repo (`ldn`, `tjoda`, `jotta`) should be under its schedule
   interval. Also `time() - push_time_seconds` for pushgateway staleness.
7. **Storage** — `zfs_pool_health != 0`, and
   `100 * zfs_pool_allocated_bytes / (zfs_pool_allocated_bytes + zfs_pool_free_bytes)`.
   Warn above 80.
8. **Certs** — `(probe_ssl_earliest_cert_expiry - time())/86400 < 21`.
9. **Deploy drift** — compare `nixos-version --json | jq -r .configurationRevision`
   on each host against `git rev-parse HEAD` in `~/git/dotfiles`. All hosts
   should share one revision. Divergence _between hosts_ is the real
   signal; lagging master by a few commits is normal.
10. **CI** — garnix, creds from `.envrc` via setec:
    ```sh
    direnv exec . sh -c 'curl -s -H "Authorization: Bearer $GARNIX_TOKEN" \
      "$GARNIX_SERVER/api/commits/$(git rev-parse HEAD)"'
    ```
    Check the last 3-4 commits, not just HEAD — that separates a chronic
    failure from a flake. Builds with no `status` key are still pending.

## Judging

Every alert is one of three things. Say which.

- **Real** — a service is degraded. Give the blast radius and the next step.
- **Monitoring gap** — the thing is fine, the probe cannot see it. Usually
  a missing ACL port or a stale target list. Fix the monitoring, not the
  service.
- **Expected** — known, accepted, or already silenced. One line, no more.

Before calling anything real, prove the failure from the affected host, not
from Prometheus. `systemctl is-active`, `ss -lntp`, `</dev/tcp/host/port`.
A probe failing while the daemon is listening means the path is blocked,
not the service.

Trace to origin. `TailnetServiceDown` on a port has a policy answer in
`~/git/infrastructure/tailscale/policy.hujson` — check both the grant rules
and the `tests`/`deny` blocks at the bottom, because a probe may be blocked
_on purpose_ and the alert is then the bug.

Alert rules live in `~/git/dotfiles/machines/core.oracldn/monitoring.nix`.
Read the `expr` and its comment before believing a summary line — several
rules carry deliberate exclusions that explain "impossible" firings.

## Output

```
FIRING: n   DOWN: n   CI: ok/fail   BACKUPS: ok/stale
```

Then, worst first, one block per finding: what, why, what to do. Skip
everything healthy — say "rest green" and stop. No tables of things that
are fine.
