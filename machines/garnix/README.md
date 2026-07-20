# garnix CI on gigabuilder

Self-hosted [garnix](https://github.com/garnix-io) CI (GitHub-only), running as an
Incus VM (`garnix`, `10.68.10.10`) on gigabuilder, with the **host as the remote
nix builder**. Public at `https://garnix.kradalby.no` (gigabuilder's nginx
TLS-terminates → VM `:80`); everything else stays on the tailnet / incusbr0.

## Why this topology

garnix evaluates and runs **untrusted code from GitHub**. The parts that touch it
are isolated from the box that holds the cache signing key and runs other VMs:

```
Incus VM "garnix" (10.68.10.10, on the tailnet)
  ├─ coordinator: webhooks · flake eval · secrets · postgres · opensearch · nginx
  └─ action-runner: untrusted run/test in krun microVMs   ← needs /dev/kvm (nested virt)
        │  remoteBuilders.hosts = [gigabuilder] → distributedBuilds, VM max-jobs=0
        ▼
gigabuilder host nix-daemon: builds in the nix sandbox → /nix/store → tsnixcache
```

A coordinator/runner compromise is contained in a KVM guest; realisation runs on
the 16c/64GB host (nix sandbox = the standard build trust boundary) and built
paths feed `tsnixcache` for free. Cost: the action-runner needs `/dev/kvm`, so the
VM runs with nested virt (AMD `kvm-amd`).

## Troubleshooting

### Disk full → postgres down

The one failure that has taken the service down. gigabuilder does the building, but
nix copies each output closure **back** to this VM's store, so it fills; a burst of
pushes once overran the hourly GC and hit 100%, crashing postgres into recovery
(every API returns 500, "Something went wrong" in the UI). Prevention is encoded in
`default.nix` (`nix.settings.min-free`/`max-free` GC continuously under pressure +
`garnix.custom-gc.targetPercent = 60`). Recover:

```bash
incus exec gigabuilder:garnix -- df -h /nix          # confirm 100%
incus exec gigabuilder:garnix -- nix-collect-garbage  # or start the custom-gc unit
incus exec gigabuilder:garnix -- systemctl restart postgresql garnixServer
```

This VM's store is disposable (durable copies live on gigabuilder/tsnixcache), so
worst case: recreate the VM.

### vCPU starvation → ~80-min resets

Under heavy load the offloaded builds saturate all 32 host cores, the VM's vcpus
stop getting scheduled (`hrtimer: interrupt took …ns` in the guest journal), and
incus resets it (`incusd: Instance stopped … reason=disconnect`, ~every 80 min).
Not a memory problem. Fixed by CPU isolation, **deployed**: VM pinned to cores
`0-3` (`limits.cpu = "0-3"` in `gigabuilder_instances.tf`), host builds confined to
`4-31` (`nix-daemon` `CPUAffinity = "4-31"` in `../gigabuilder/builder.nix`). incus
can't switch a _running_ VM to pinning — reconcile once stopped (`incus stop` →
`incus config set … limits.cpu 0-3` → `incus start`); the `.tf` stays source of
truth.

### Eval / OOM overload

garnix hard-codes SaaS-sized concurrency; on the 16 GiB VM a big repo (headscale,
~170 targets) fans out ~50 concurrent evals (~0.5–1 GiB each) → global OOM that
kills OpenSearch and nix. The fork makes the pools env-configurable — set in
`default.nix`: `GARNIX_NIX_EVAL_POOL_SIZE = "6"`, `GARNIX_FOD_CHECK_POOL_SIZE = "4"`.
Keep the VM at 16 GiB; gigabuilder needs its 64 GiB for the offloaded builds.
`services.systemd` OOMScoreAdjust (garnixServer `+500`, postgres/opensearch `-800`)
makes garnix's own tree the OOM victim instead of the datastores.

### Build concurrency / starvation

Realisation used to be unbounded: every attribute of a flake fired `nix build` at
once, and because the build timeout wrapped the _queue wait_, a big push left tail
builds spuriously timing out while they waited for a slot (→ repush → worse). The
fork adds a build-dispatch pool acquired _outside_ the timeout; set in `default.nix`:
`GARNIX_NIX_BUILD_POOL_SIZE = "8"`, kept in step with the gigabuilder remote-builder
`maxJobs = 8` (8 × 4 cores/job ≈ the 28 build cores). Backlogged builds now wait
untimed instead of failing. Raise both together if gigabuilder grows.

### Queue / reset

State is postgres db `garnix`. `builds.status` is an enum, `NULL` = pending. garnix
does **not** resume orphaned pending builds after a crash — but the fork now runs a
**startup reconciler** (`Garnix.Reconcile.reconcileOrphanedBuilds`, called before
webhooks are served) that, for every still-`NULL` build, first **closes its GitHub
check run** (best-effort — bounded one-shot, so not the crash-loop that trips the 403
secondary limit) so a PR no longer hangs on a forever-spinning required check, then
marks it `cancelled` in the DB. A restart thus self-heals without a repush. garnix
still never rebuilds _superseded_ commits; their checks sit `in_progress` forever
(harmless; the PR uses the latest commit). Manual reset is still SQL on `builds`:

```bash
incus exec gigabuilder:garnix -- bash -lc "sudo -u postgres psql -d garnix"
```

`denylist(repo_user, repo_name)` stops a repo entirely — but don't denylist
headscale, it's the reason this builder exists.

### GitHub rate limits / stale checks

garnix retries only 5xx, not 403 — no secondary-rate-limit / `Retry-After` backoff.
A crash loop re-dispatches the whole check set repeatedly → GitHub secondary limit
(403) → dropped check-run updates → stale `in_progress`. Fix is stability (+ an
upstream backoff, worth reporting).

### Deploy

- `colmena apply --on garnix` — the VM is on the tailnet, so colmena reaches it by name.
- Incus/VM config (CPU pinning, sizing, nested virt) is OpenTofu in
  `~/git/infrastructure`, never ad-hoc `incus config set`.
- A gigabuilder deploy restarts `incus`, bouncing the VM + the `:8443` API; it
  auto-returns via power-state restore, so sequence any tofu apply after it settles.

## Health checks

- `incus info gigabuilder:garnix` — status; `reason=disconnect` = crash/reset;
  guest `hrtimer: interrupt took` = vcpu starvation; `journalctl -k | grep oom-kill`
  = memory; `df -h /nix` = the disk-full failure above.
- API via setec creds (`GARNIX_TOKEN` / `GARNIX_SERVER`, from `.envrc`):
  `$GARNIX_SERVER/api/whoami`, `$GARNIX_SERVER/api/commits/{sha}`.

---

## Reference

### Source

The `garnix-ci` flake input tracks the fork **`github:kradalby/garnix/integration`**
— it carries our deploy tweaks (env-configurable eval/FOD pools,
`GARNIX_DEFAULT_CONFIG`, the owner allowlist below). `znaniye/garnix-ci` is the
upstream-of-record to rebase onto and report bugs to. Pull updates with
`nix flake update garnix-ci` (a rev bump forces a backend recompile).

### Access control (allowlist)

Upstream garnix has **no allowlist** — gating is denylist-only, so any GitHub
account that installs the App would get builds (arbitrary code on the build
sandbox). The fork adds an allowlist enforced in `assertIsAllowedToBuild`, read from
`GARNIX_ALLOWED_OWNERS` (comma-separated); `default.nix` sets it to
`kradalby,juanfont`. Empty/unset ⇒ allow-all. Changing the list is a config
redeploy, no recompile. This survives an App/DB re-creation; don't rely on GitHub
App visibility (it can't express "these two accounts").

### TLS / proxy

gigabuilder's nginx is the single public TLS terminator. garnix's own nginx
hardcodes `forceSSL`/`enableACME`, so `default.nix` overrides that vhost to plain
HTTP (a private-IP ACME cert can't validate). Host proxies
`https://garnix.kradalby.no` (DNS-01 cert) → `http://10.68.10.10:80`; the backend
still emits https links via `services.garnixServer.url`. Public DNS:
`garnix.kradalby.no` A → `194.32.107.146` (Cloudflare).

### DB + OpenSearch (co-located)

Plain NixOS `services.postgresql` (postgresql_18, loopback trust auth, db+user
`garnix`) and `services.opensearch` (single-node, `127.0.0.1:9200`), talked to over
loopback with `database.ssl.mode = "disable"`. Deliberately **not** the fork's
`database.nix` / `opensearch` modules, which target separate TLS-fronted hosts via
sops — overkill for one co-located VM. Tradeoff: no built-in DB backups / TLS /
exporters (add later if wanted). The `garnix-*` db/opensearch secrets are still
staged by the server module but go unused under trust auth.

### The Incus VM (infra-as-code)

Declared in `~/git/infrastructure/incus/gigabuilder_instances.tf`, `tofu apply` from
the laptop (which has the `gigabuilder` incus remote). `type = virtual-machine`,
`image = images:nixos/unstable`, `limits.cpu = "0-3"`, `limits.memory = "16GiB"`,
`security.secureboot = false`, `linux.kernel_modules = kvm_amd`,
`raw.qemu = "-cpu host"` (nested virt); nic bridged `parent = incusbr0`,
`ipv4.address = 10.68.10.10`; root disk `pool = default` (gigabuilder's vmpool ZFS),
`size = 80GiB`. Verify nested virt: `incus exec gigabuilder:garnix -- ls -l /dev/kvm`.

### Secrets (ragenix)

Twelve `garnix-*.age` secrets, encrypted to the garnix host key (added as a
recipient in `secrets/secrets.nix`):

| secret (`secrets/`)                | how to make it                                           |
| ---------------------------------- | -------------------------------------------------------- |
| `garnix-database-password.age`     | `openssl rand -hex 32`                                   |
| `garnix-github-app-id.age`         | from the GitHub App                                      |
| `garnix-github-app-pk.age`         | GitHub App private key (PEM)                             |
| `garnix-github-client-id.age`      | from the GitHub App                                      |
| `garnix-github-client-secret.age`  | from the GitHub App                                      |
| `garnix-github-webhook-secret.age` | random; same value in the App                            |
| `garnix-opensearch-credential.age` | random (unused under trust auth)                         |
| `garnix-jwt-key.age`               | `Servant.Auth.Server.writeKey`                           |
| `garnix-repo-secrets-key.age`      | age **private** key (`age-keygen`)                       |
| `garnix-repo-secrets-key-pub.age`  | matching age **public** key                              |
| `garnix-action-runner-ssh.age`     | ssh keypair; pub → `garnix.actionRunner.authorizedKey`   |
| `garnix-remote-builder-ssh.age`    | ssh keypair; pub → gigabuilder `builder.nix` nix-ssh key |

### GitHub App

Admin flow: log in as `adminGithubLogin` (`kradalby`), open
`https://garnix.kradalby.no/garnix-admin`, "Submit to GitHub" to create the App,
then fill the app id / client id+secret / private key / webhook secret secrets and
redeploy.
