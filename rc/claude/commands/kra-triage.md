---
description: Triage homelab alerts and health signals
---

Triage the fleet. Report only what needs a human. Be brief.

## Access

Prometheus/Alertmanager are tailnet VIP services on **tcp:80/443** — reach
them by short name, no ssh hop:

```sh
curl -s 'http://alertmanager/api/v2/alerts?silenced=false&inhibited=false&active=true'
curl -s -G http://prom/api/v1/query --data-urlencode query@- <<< 'up == 0'
```

Feed PromQL on stdin (`query@-`). Inline `--data-urlencode "query=..."`
gets mangled by nested shell quoting.

If a name does not resolve, that is the ACL, not DNS: an ungranted VIP is
absent from MagicDNS entirely. The grant is in
`~/git/infrastructure/tailscale/policy.hujson`.

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
10. **CI** — garnix, via `garnixlogs`: plain text, no auth, no setec, private
    repos included. Reach for this first; it is the whole point of it.

    ```sh
    curl -s http://garnixlogs/dotfiles                 # recent commits
    curl -s "http://garnixlogs/$(git rev-parse HEAD)"  # summary + each failed build's log
    curl -s "http://garnixlogs/<build-id>?follow"      # stream one still running
    ```

    Commit hashes must be the full 40 characters. Check the last 3-4 commits,
    not just HEAD — that separates a chronic failure from a flake.

    Only if garnixlogs itself is down, go to the API. `$GARNIX_TOKEN` is not a
    JWT, it is the Basic-auth password that mints one; sent as a Bearer token
    it reads as anonymous, which answers on public repos and returns a
    misleading "not found" on private ones. Check `/api/whoami` before
    believing a 404.

    ```sh
    direnv exec . sh -c '
      jwt=$(curl -s -u "kradalby:$GARNIX_TOKEN" -X POST "$GARNIX_SERVER/api/auth/jwt" | jq -r .token)
      curl -s -H "Authorization: Bearer $jwt" "$GARNIX_SERVER/api/commits/$(git rev-parse HEAD)"'
    ```

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
