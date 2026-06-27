# garnix CI on gigabuilder — runbook (temporary)

Self-hosted garnix CI (GitHub-only) as an **Incus VM on gigabuilder**, with the
**host as the remote nix builder**. Delete this file once the box is live and the
scaffold is activated.

## Why this topology

garnix evaluates and runs **untrusted code from GitHub**. We isolate the parts
that touch it from the box that holds the cache signing key and runs other VMs:

```
Incus VM "garnix" (10.68.10.10, joins tailnet)
  ├─ coordinator: webhooks · flake eval · secrets · postgres · opensearch · nginx
  └─ action-runner: untrusted run/test in krun microVMs   ← needs /dev/kvm (nested virt)
        │  remoteBuilders.hosts = [gigabuilder] → distributedBuilds, VM max-jobs=0
        ▼
gigabuilder host nix-daemon: builds in the nix sandbox → /nix/store → tsnixcache
```

- Coordinator/runner compromise is contained in a KVM guest.
- Realisation still runs on the 16c/64GB host (nix sandbox = the standard build
  trust boundary), and built paths feed `tsnixcache` for free.
- Cost: the action-runner needs `/dev/kvm` → the VM needs **nested virt** (AMD
  `kvm-amd`, supported). If we run few garnix "actions" (vs plain builds/checks),
  the runner matters less and can be disabled/offloaded later.

## Source

The `garnix-ci` flake input tracks **`github:znaniye/garnix/selfhost`** directly
— Samuel (znaniye) is the active upstream-of-record. Pull his fixes with
`nix flake update garnix-ci`. (No kradalby fork branch is needed for the input;
the local `integration`/`selfhost` branches at `~/git/garnix` are just a working
mirror if you ever want to carry local patches.)

## Blockers / gates (in order)

1. **gigabuilder live.** Its own registration gate must be cleared first.
2. **VM created** (below) so a host key exists to rekey secrets against.

## Activation checklist (what to uncomment)

- `flake.nix`: the `"garnix" = box.nixosBox {…}` entry (the `garnix-ci` input is
  already active).
- `machines/gigabuilder/default.nix`: the `./builder.nix` import.
- `machines/gigabuilder/web.nix`: the `garnix.kradalby.no` vhost line.
- `machines/gigabuilder/builder.nix`: drop in the VM's remote-builder **public** key.
- `machines/garnix/default.nix`: set `githubAppName` and
  `garnix.actionRunner.authorizedKey`. (DB/OpenSearch already wired — see below.)
- `nix flake lock` to pin garnix-ci; `colmena apply --on gigabuilder garnix`.

## Create the Incus VM (on gigabuilder)

VM (not container) — containers can't safely provide `/dev/kvm`.

```sh
# nested virt on the host (AMD); persist via kernel module options if needed
cat /sys/module/kvm_amd/parameters/nested        # expect Y/1

# launch a NixOS VM on the incus bridge, nested virt enabled, static IP
incus init images:nixos/unstable garnix --vm \
  -c limits.cpu=8 -c limits.memory=12GiB \
  -c security.secureboot=false \
  -c linux.kernel_modules=kvm_amd
incus config device override garnix root size=80GiB
incus config device set garnix eth0 ipv4.address=10.68.10.10
# expose KVM for the action-runner (nested):
incus config set garnix raw.qemu='-cpu host'      # pass host CPU flags (SVM) to guest
incus start garnix
```

Install NixOS onto the VM disk so it matches `common/incus.nix`
(`/dev/sda1` vfat ESP + `/dev/sda2` ext4 root), join tailscale, then manage it
with the flake via Colmena like any other host. Verify `ls -l /dev/kvm` inside
the guest before enabling the action-runner.

## DB + OpenSearch (co-located, already wired)

DONE in `machines/garnix/default.nix`: plain NixOS `services.postgresql`
(postgresql_18, loopback trust auth, db+user `garnix`) and `services.opensearch`
(single-node, `127.0.0.1:9200`). The backend talks to both over loopback with
`database.ssl.mode = "disable"`.

Deliberately NOT using the fork's `nix/modules/database.nix` /
`opensearch/nixos-module.nix`: those target SEPARATE, TLS-fronted hosts — postgres
forces `ssl=true` with an ACME cert per `fqdn` + `verify-full` (port 9178), and
opensearch sits behind nginx+basic-auth with its own cert, both via sops. That's
why the `selfhost` example externalizes them. For a single co-located VM where the
connections never leave the box, plain loopback services are simpler and correct;
the tradeoff is no built-in DB backups / TLS / exporters (add later if wanted).

The `garnix-*` db/opensearch secrets are still staged by the server module but go
unused under trust auth — fine to leave as placeholders.

**VM sizing:** OpenSearch runs a JVM. The `limits.memory=8GiB` above is tight with
postgres + the garnix backend + nested action-runner microVMs — bump to **12–16GiB**.

## TLS / proxy

gigabuilder's nginx is the single public TLS terminator. garnix's own nginx
hardcodes `forceSSL`/`enableACME` on its vhost (and `devMode` would disable
remoteBuilders), so `machines/garnix/default.nix` overrides that vhost to plain
HTTP (`enableACME`/`forceSSL` `mkForce false`). The host proxies
`https://garnix.kradalby.no` (DNS-01 cert) → `http://10.68.10.10:80`. The backend
still emits https links via `services.garnixServer.url`.

Public DNS: `garnix.kradalby.no` A → `194.32.107.146` (Cloudflare). GitHub
webhooks reach the public host; everything else is tailnet/incusbr0.

## Secrets (ragenix)

Generate, encrypt to `secrets/garnix-*.age`, and add the garnix host key as a
recipient in `secrets/secrets.nix`:

| secret file (`secrets/`)              | how to make it |
|---------------------------------------|----------------|
| `garnix-database-password.age`        | random (`openssl rand -hex 32`) |
| `garnix-github-app-id.age`            | from the GitHub App |
| `garnix-github-app-pk.age`            | GitHub App private key (PEM) |
| `garnix-github-client-id.age`         | from the GitHub App |
| `garnix-github-client-secret.age`     | from the GitHub App |
| `garnix-github-webhook-secret.age`    | random; set same value in the App |
| `garnix-opensearch-credential.age`    | random (basic-auth password) |
| `garnix-jwt-key.age`                  | `Servant.Auth.Server.writeKey` (see fork docs) |
| `garnix-repo-secrets-key.age`         | age **private** key (`age-keygen`) |
| `garnix-repo-secrets-key-pub.age`     | matching age **public** key |
| `garnix-action-runner-ssh.age`        | ssh keypair; pub → `garnix.actionRunner.authorizedKey` |
| `garnix-remote-builder-ssh.age`       | ssh keypair; pub → gigabuilder `builder.nix` `nix-ssh` authorizedKeys |

(S3 cache keys only if `s3Cache.enable = true` later.)

## GitHub App

Use the admin flow: log in as `adminGithubLogin` (`kradalby`), open
`https://garnix.kradalby.no/garnix-admin`, "Submit to GitHub" to create the App,
then copy app id / client id+secret / private key / webhook secret into the
secrets above and redeploy.

## Verify (once live)

- `nix flake check`; `nix build .#nixosConfigurations.garnix.config.system.build.toplevel`.
- VM offloads: `nix store ping --store ssh-ng://nix-ssh@10.68.0.1` works; a CI
  build runs on the host (`max-jobs=0` in VM) and the output resolves via tsnixcache.
- Nested virt: `/dev/kvm` present in the VM; an action build starts a krun microVM.
- E2E: push to a test repo → webhook → status reported on the commit.

## Decisions

- **s3Cache: skipped.** Outputs land in the gigabuilder store (via
  `remoteBuilders`) that tsnixcache already serves — no separate S3 cache.
- **action-runner: required** (co-located → needs nested virt).
- **remoteBuilders: gigabuilder only** (`10.68.0.1`, `nix-ssh`).

## Deferred

- multi-forge/Gitea (GitHub-only for now).
