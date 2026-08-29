---
name: deploy
description: Deploy the NixOS/darwin fleet from master with colmena. Use for any fleet deploy, host reboot, or post-deploy verification in this repo.
---

# Deploy the fleet

## Scope

Deploy THIS repo to the hosts declared in `flake.nix` / `machines/`. Do not
write features, do not open PRs, do not deploy another repo. A host not in
`machines/` is out of scope — say so and stop. One host per deploy; never
`colmena apply` without `--on`.

## Preconditions

`colmena` in this devShell is wrapped: `apply`, `apply-local` and
`upload-keys` refuse unless the repo is on `master`, clean, in sync with
`origin`, and has nothing unpushed. If it refuses, report the message and
stop. Do not commit, push, checkout, stash or fetch to make it pass — that is
the human's call. `git-ready` runs the same check on demand.

Confirm CI is green for `HEAD`:

    gh pr checks

Fall back to the garnix API when `gh` is unclear — it reports `pending 0s`
for a build that is actively running, which looks identical to one that was
never dispatched:

    direnv exec . sh -c 'curl -s -H "Authorization: Bearer $GARNIX_TOKEN" \
      "$GARNIX_SERVER/api/commits/$(git rev-parse HEAD)"'

A build with no `status` key is pending, not failed; a real `start_time` on
`$GARNIX_SERVER/api/build/<id>` proves it is running. aarch64 is slow — check
the cache is populated rather than assuming a stall.

## Preview

    nix flake check
    colmena build --on <node> --keep-result     # GC roots land in ./.gcroots
    ssh root@<node> nixos-version --json | jq -r .configurationRevision
    git log --oneline <that rev>..HEAD

That last range is what is actually landing. A host tens of commits behind is
not a one-service deploy — it lands the whole backlog, including deliberate
deletions made months ago.

The real closure diff cannot happen here: hosts have `max-jobs = 0`, so the
new closure is not on the target until it is pushed. That is step 2 of
Execute, and it is the last exit point.

## Execute

One host at a time. Wait for Verify to pass before starting the next.

Capture the baseline first — Verify depends on it:

    ssh root@<node> 'systemctl list-units --state=running --no-legend | wc -l'
    ssh root@<node> 'systemctl list-unit-files --state=enabled --type=service \
      --no-legend | awk "{print \$1}" | grep -v @ \
      | xargs -r -I{} sh -c "systemctl is-active --quiet {} || echo {}" | sort'

1.  `colmena apply boot --on <node>` — idempotent: yes; self-severing: no.
    Pushes the closure and arms the next boot. Touches no running unit.

2.  Read the diff. After step 1 `/run/current-system` is still the old
    generation while `/nix/var/nix/profiles/system` is the new one:

        ssh root@<node> 'nix store diff-closures /run/current-system /nix/var/nix/profiles/system'

    Read the **removals**, not just the additions. Escalate here — not after
    the reboot — if it shows any of:
    - a kernel or zfs-kernel change,
    - a tailscale/tailscaled version change,
    - a service disappearing that you did not expect,
    - anything under `secrets/` moving,
    - a closure delta far larger than the commit range explains.

    Step 1 already armed the next boot, so backing out is not "do nothing".
    Undo it explicitly before any reboot, planned or not:

        ssh root@<node> 'nix-env -p /nix/var/nix/profiles/system --rollback && \
          /nix/var/nix/profiles/system/bin/switch-to-configuration boot'

3.  `ssh root@<node> systemctl reboot` — idempotent: yes; self-severing: yes.

**Never `colmena apply switch`, and never `--reboot`.** colmena rides SSH over
the tailnet. An activation that restarts tailscaled severs colmena's own
connection, `switch-to-configuration` dies as a child of that session, and the
host is left with units **stopped but never started** — reporting
`is-system-running: running` with zero failed units, because a cleanly stopped
unit is invisible to the failed count. That gutted storage.ldn for 26 hours
and took 12 services down on core.oracldn. `apply boot` cannot sever anything
because it never restarts a unit, and the reboot then activates the whole
generation from PID 1, which also repairs a previously half-applied one.
`--reboot` is a live switch _plus_ a reboot, so it keeps the severing window —
it is not the safe option.

### Order

1. **x86** — `home.ldn`, `storage.ldn`, `ts1p.ldn`, `core.tjoda`,
   `storage.bassan`, `gigabuilder`, `garnix`.
2. **arm64** — `core.oracldn`, `dev.oracfurt`, `rpi5.ldn`. Check the cache is
   populated first: `nix run .#cache-arm`. Without it they build under
   emulation, which is slow enough to look hung.
3. **dev.ldn** — after approval. Last, because it is the sole builder: every
   other host has `max-jobs = 0` and needs it up.

### Per-host

- **dev.ldn** is this workstation. `ssh root@dev-ldn` is SSH-to-self and is
  refused; that is correct, not drift. Deploy it locally:
  `PATH=/run/wrappers/bin:$PATH colmena apply-local --sudo --node dev.ldn`
  (the real sudo lives in `/run/wrappers/bin`).
- **gigabuilder** hosts the Incus guests `garnix`, `ts1p.ldn`, `dev.ldn`,
  `home.ldn`, `storage.ldn`. Deploying it restarts incus and bounces all of
  them. Deploy it alone and let it settle.
- **darwin** (`kratail2`, `krair`) are not colmena nodes; deploy on the
  machine itself with `darwin-rebuild switch --flake .#<host>`.
  `kradalby-llm` is standalone home-manager:
  `home-manager switch --flake .#ubuntu@kradalby-llm -b backup`.

If a switch did sever mid-activation, finish it detached so it survives the
disconnect:

    ssh root@<node> 'systemd-run --unit=complete-activation --collect \
      --service-type=oneshot /run/current-system/bin/switch-to-configuration switch'

## Verify

Three outcomes: pass, fail, **inconclusive**. Inconclusive stops and asks — it
is not "probably fine".

Run `/kra-triage` after the host is back and read alertmanager; it covers the
fleet-wide signals this list does not.

1.  `ssh root@<node> systemctl is-system-running` — `running` = pass,
    `degraded` = fail, no answer inside the reboot window = inconclusive.
2.  Running-unit count against the Execute baseline. **Fewer units than before
    = fail**, even with zero failed units.
3.  `ssh root@<node> nixos-version --json | jq -r .configurationRevision` must
    equal `git rev-parse HEAD`. `DIRTY` means it was built from an unclean tree.
4.  Prometheus, by short name. PromQL on stdin — inline `query=` gets
    mangled by nested quoting.

        curl -s -G http://prom/api/v1/query --data-urlencode query@- <<< 'up == 0'

    No data returned = inconclusive, never pass.

5.  Alerts:

        curl -s 'http://alertmanager/api/v2/alerts?silenced=false&inhibited=false&active=true'

    A burst during the reboot window is expected — `NodeExporterDown{target=<node>}`
    inhibits its dependents by design. What matters is that it clears. The
    `Watchdog` alert must be present; its absence means the dead-man is broken.

6.  On home-manager hosts (dev.ldn, rpi5.ldn) check **user** units too. A failed
    home-manager activation freezes user services on the old generation, so the
    system units can look perfect while nothing new was adopted.

7.  Nothing enabled is sitting stopped. This is the failure mode a severed
    switch leaves behind, and it is invisible to `--failed` and to
    `is-system-running`:

        ssh root@<node> 'systemctl list-unit-files --state=enabled --type=service \
          --no-legend | awk "{print \$1}" | grep -v @ \
          | xargs -r -I{} sh -c "systemctl is-active --quiet {} || echo {}" | sort'

    Diff against the same command captured in Execute. Roughly 20 lines is
    normal — oneshots that ran and exited — so only entries that are **new**
    since the baseline count. Any of those is a fail: start it and find out
    why it did not come up.

Prove a failure from the host before calling it real: `systemctl is-active`,
`ss -lntp`. A probe failing while the daemon is listening means the path is
blocked, not the service.

## Rollback

Trigger: any Verify check fails, or two consecutive inconclusive results.

    ssh root@<node> 'nixos-rebuild --rollback switch'
    ssh root@<node> systemctl reboot     # if the rollback is itself self-severing

Only 5 generations are kept (`boot.loader.*.configurationLimit` in
`common/nix.nix`) and GC deletes older than 10 days — rollback goes no deeper.

If a host is out of disk, `emergency-full-disk` is on every server
(`profiles/server.nix`). It frees a 2 GB ballast file, vacuums the journal and
collects garbage — but it also **deletes all but 2 system generations**, so
running it destroys the rollback depth above. Roll back first if you still
might need to, then reclaim.

Cannot be rolled back: agenix key rotation, filesystem or dataset changes,
anything that migrated data on disk. Those are forward-fix only.

Physical access decides whether a bad reboot is recoverable. Ask which site a
host is at rather than trusting a list here — the fleet moves:

- **Leiden, NL** — hands available.
- **Sandefjord, NO** — colo, provider console only.
- **Sandefjord, NO** — Bassan's house.
- **Tjodalyng, NO** — no hands, no console, no second host. Every reboot is
  one-way.
- **Oracle Cloud** — OCI web console.

`.ldn` means Leiden. `oracldn` means Oracle London. Both are correct — do not
"fix" either.

## Escalate

Ask before these, and only these. Everything else proceeds.

- **Every reboot.** Execute step 3 does not run until the human says so.
- Any finding from the Execute step-2 closure-diff list.
- Deploying `dev.ldn` at all — it is the builder the rest of the fleet needs.
- Deploying `core.tjoda` at all — no hands, no console, and it is the LAN
  router. State the closure diff and wait.
- Deploying `gigabuilder` — it bounces five guests, including CI.
- A rollback that Rollback says cannot be rolled back.
- garnix red on HEAD, or the x86 checks amber for over an hour.
- Anything the wrapped `colmena` refused.

## Notes

- Deploy drift is `configurationRevision` diverging **between** hosts. All
  hosts lagging master together is normal.
- `root@<node>` works over Tailscale SSH; `sudo` as `kradalby` over ssh does
  not (no askpass). Use root.
- `nix flake check` and `colmena build` can outrun a tool-call timeout on a
  cold cache. Run them in the workspace's shell pane and watch, not inline.
- `rnb -m dev-ldn -- colmena apply …` forces the build onto a remote builder.
  On dev.ldn `rnb` must run as root — `kradalby` is not a nix trusted-user there.
