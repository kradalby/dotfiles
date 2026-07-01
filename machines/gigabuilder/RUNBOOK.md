# gigabuilder — install runbook

Bare-metal x86_64 (16-core AMD, 64GB, 4 NICs, 2×500GB NVMe), public IP
194.32.107.146. Becomes an Incus VM host + tsnixcache binary cache.

The branch already contains all declarative config; the `gigabuilder` entry in
`flake.nix` `nixosConfigurations` is **commented out** until the steps below are done.

---

## 0. Build + flash the installer ISO (from your workstation)

```bash
# fill the key locally — do NOT commit it
$EDITOR flake.nix      # bootstrapSecrets.tsAuthKey = "tskey-auth-...."
nix build .#installer
git checkout flake.nix # revert the secret; the ISO already embeds it

sudo dd if=result/iso/nixos-*-x86_64-linux.iso of=/dev/sdX bs=4M conv=fsync status=progress
```

Boot it on the box. It auto-joins tailscale, brings up wan0 (static 194.32.107.146),
and accepts SSH from isc / ldn / tjoda + tailscale. SSH in to install.

---

## 1. Disk layout (run on the target, in the installer)

```bash
# --- 0. wipe any prior install holding the disks (else the kernel can't
#        re-read the partition table → "cannot resolve path /dev/nvme0n1p2") ---
vgchange -an 2>/dev/null          # deactivate stray LVM (e.g. ubuntu-vg)
zpool export -a 2>/dev/null       # release any auto-imported pool
mdadm --stop /dev/md? 2>/dev/null # stop any auto-assembled md array
swapoff -a 2>/dev/null
dmsetup ls                        # must be empty before continuing
for d in /dev/nvme0n1 /dev/nvme1n1; do wipefs -a "$d"; sgdisk --zap-all "$d"; done
partprobe /dev/nvme0n1; partprobe /dev/nvme1n1; udevadm settle
lsblk                             # both disks bare

# --- NVMe0 -> rpool: 2GiB ESP (kernels never fill /boot) + ZFS root ---
parted /dev/nvme0n1 -- mklabel gpt
parted /dev/nvme0n1 -- mkpart ESP fat32 1MiB 2GiB
parted /dev/nvme0n1 -- set 1 esp on
parted /dev/nvme0n1 -- mkpart primary 2GiB 100%
mkfs.vfat -n boot /dev/nvme0n1p1

zpool create -O mountpoint=none -O atime=off -O compression=zstd \
  -O xattr=sa -O acltype=posixacl rpool /dev/nvme0n1p2
zfs create -o mountpoint=legacy rpool/root
zfs create -o mountpoint=legacy rpool/nix          # /nix/store = the served cache

# --- NVMe1 -> vmpool: dedicated Incus storage (whole disk) ---
zpool create -O atime=off -O compression=zstd vmpool /dev/nvme1n1

# --- mount for install ---
mount -t zfs rpool/root /mnt
mkdir -p /mnt/boot /mnt/nix
mount -t zfs rpool/nix /mnt/nix
mount /dev/disk/by-label/boot /mnt/boot
```

> Device names assume NVMe0=`nvme0n1`, NVMe1=`nvme1n1` — verify with `lsblk`.
> `vmpool` is created but NOT mounted; Incus consumes it as a storage pool.

---

## 2. Generate hardware config + host key (on the target)

```bash
nixos-generate-config --root /mnt
# copy /mnt/etc/nixos/hardware-configuration.nix over
#   machines/gigabuilder/hardware-configuration.nix   (replaces the placeholder)
hostid                                 # → set networking.hostId in default.nix
                                       #   (must match, else ZFS root needs force-import)

# Pre-generate the host SSH key NOW so ragenix secrets can be encrypted to it
# before install. It lives on rpool/root (/mnt) and the installed system reuses it.
install -d -m755 /mnt/etc/ssh
ssh-keygen -t ed25519 -N "" -f /mnt/etc/ssh/ssh_host_ed25519_key
cat /mnt/etc/ssh/ssh_host_ed25519_key.pub   # → secrets/secrets.nix
```

---

## 3. Secrets (ragenix, from your workstation)

In `secrets/secrets.nix`: add the host pubkey from step 2, then grant gigabuilder the
`publicKeys` of:
- `tailscale-preauthkey`
- `headscale-client-preauthkey`
- `headscale-sfiber-client-preauthkey` (already exists — just add gigabuilder)

Create ONE new secret:
- `tsnixcache-sign-key.age`  ← `tsnixcache key generate` (encrypt the private half;
  keep the public half for `metadata/tsnixcache.nix` client config)

The tsnixcache tsnet nodes reuse the host's reusable join keys
(`tailscale-preauthkey` for SaaS, `headscale-sfiber-client-preauthkey` for
sfiber), so no cache-specific authkey is needed.

```bash
ragenix --rekey
# uncomment the "gigabuilder" = box.nixosBox { ... } block in flake.nix
nix build .#nixosConfigurations.gigabuilder.config.system.build.toplevel   # eval check
git add -A && git commit && git push          # the install fetches the branch
```

---

## 4. Install (on the target)

colmena only deploys to an ALREADY-running NixOS — the first time you must
`nixos-install`. The host key from step 2 lets ragenix decrypt secrets during
activation; `gigabuilder` eval never touches the local `ts1p` flake input, so a
flake install on the box is fine.

```bash
nixos-install --flake github:kradalby/dotfiles/gigabuilder#gigabuilder
#   omit --no-root-passwd → you'll be prompted for a root password (console
#   fallback); SSH key auth is configured either way.
reboot
```

Boots into the installed system, brings up wan0 + tailscale. From here on, deploy
with `colmena apply --on gigabuilder` from the workstation.

---

## 5. Incus + cache

One-time Incus CLI trust for the laptop:
```bash
# on gigabuilder
incus config trust add laptop          # prints a token
# on the laptop (reachable via the advertised /16 over tailscale)
incus remote add gigabuilder 10.68.0.1:8443 --token <token>
```

---

## ZFS / nixpkgs version note

The installer is built from nixpkgs-unstable (ZFS 2.4.x), so the pool it creates
enables 2.4 features (e.g. `com.truenas:block_cloning_endian`). The 25.11 fleet
ships ZFS 2.3.7, which CANNOT import such a pool → stage-1 boot fails with
"cannot import rpool ... unsupported feature". Fix: gigabuilder tracks
**nixpkgs-stable (26.05)** via `nixpkgs = inputs.nixpkgs-stable` in flake.nix,
giving ZFS 2.4.2 — new enough to import the pool. No per-host ZFS package pin.
If you hit the boot error: boot the installer, `zpool import -f rpool`, mount,
re-run `nixos-install` with the updated config.

## 6. Verify

```bash
incus network show incusbr0            # 10.68.0.1/16, dhcp 10.68.10.x
incus launch images:debian/12 t1
incus list                             # t1 has a 10.68.10.x IP
incus exec t1 -- ping -c1 1.1.1.1      # NAT/internet works
# from laptop (tailnet, /16 route approved in admin):
ping 10.68.10.<vm>
nix store info --store http://tsnixcache   # cache reachable over tailscale
```

Gotchas to check: `nft list tables` still shows the `incus` table after
`systemctl restart nftables` (else set `networking.nftables.flushRuleset = false`);
tailnet→VM forwarding (add `extraForwardRules` if `filterForward` is on).

---

## Still open

- **Incus remote**: added to the laptop ✓ — API on `gigabuilder:8443` over
  tailscale (`incusbr0` bind is `[::]:8443`, firewall keeps 8443 off wan0;
  `tag:incus` grants `tag:dev → :8443`).
- **Fleet cache wiring** (every host consume `http://tsnixcache` + push from
  macs/dev.ldn): **deferred until this branch merges to master**.
- **SSH hardening**: DONE, fleet-wide — `KbdInteractiveAuthentication = false` in
  `common/ssh.nix` (alongside the existing `PasswordAuthentication = false`).
  Safe everywhere: keys + tailscale-SSH on every host; bootstrap passwords are
  console-only.
- `networking.nix` DNS defaults to Cloudflare (provider gave none) — fine as-is.
