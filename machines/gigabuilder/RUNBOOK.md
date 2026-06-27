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

## 2. Generate hardware config

```bash
nixos-generate-config --root /mnt
# copy /mnt/etc/nixos/hardware-configuration.nix over
#   machines/gigabuilder/hardware-configuration.nix   (replaces the placeholder)
```
hostId is already pinned in `default.nix` (`b114813d`) — leave it.

---

## 3. Secrets (ragenix, from your workstation)

In `secrets/secrets.nix`: add gigabuilder's host SSH pubkey, then grant it the
`publicKeys` of:
- `tailscale-preauthkey`
- `headscale-client-preauthkey`
- `headscale-sfiber-client-preauthkey` (already exists — just add gigabuilder)

Create two NEW secrets:
- `tsnixcache-sign-key.age`  ← `tsnixcache key generate` (encrypt the private half;
  keep the public half for client substituter config later)
- `tsnixcache-tsnet-authkey.age`  ← a tailscale authkey (kradalby tailnet)

Then:
```bash
ragenix --rekey
```

---

## 4. Enable + deploy

```bash
# uncomment the "gigabuilder" = box.nixosBox { ... } block in flake.nix
nix build .#nixosConfigurations.gigabuilder.config.system.build.toplevel   # eval check
colmena apply --on gigabuilder        # first time via public-IP targetHost
```

One-time Incus CLI trust for the laptop:
```bash
# on gigabuilder
incus config trust add laptop          # prints a token
# on the laptop (reachable via the advertised /16 over tailscale)
incus remote add gigabuilder 10.68.0.1:8443 --token <token>
```

---

## 5. Verify

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

## Still open (your call)
- SSH `KbdInteractiveAuthentication = false` — hardens the `root/root`-over-PAM path;
  global (`common/ssh.nix`) vs installer-only.
- `networking.nix` DNS defaults to Cloudflare (provider gave none).
- Client wiring: `tsnixcache-client` + signing publicKey on laptop/dev hosts.
