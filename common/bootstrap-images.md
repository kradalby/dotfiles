# Build a host image

Choose [wired DHCP](../images/examples/wired/default.nix), [Wi-Fi DHCP](../images/examples/wifi/default.nix) or [static Ethernet](../images/examples/static/default.nix). From the repo root:

```sh
umask 077
host=$(mktemp -d)
cp images/examples/wired/default.nix "$host/default.nix"
$EDITOR "$host/default.nix"
authkey kradalby > "$host/join.key"
nix build .#installer-iso --override-input image-config "path:$host"
```

The profile sets the hostname and network. The Wi-Fi example takes the SSID and password directly. Keep the directory outside Git. Its plaintext credentials enter the Nix store, image and any cache that receives them. The single-use join key defaults to 24 hours.

## Install a server

1. Boot the ISO from `result/iso/` in UEFI mode. It joins Tailscale automatically.
2. Run `ssh root@HOSTNAME` with your usual [SSH key](../metadata/ssh.nix). The LAN IP also works.
3. Mount the fresh target's ext4 root (label `nixos`) at `/mnt` and its FAT EFI partition (label `ESP`) at `/mnt/boot`.
4. Run `systemctl start --no-block install-bootstrap`. It runs `nixos-install`, preserves the SSH host keys, stops Tailscale, copies its state, and powers off. SSH disconnects during handoff.
5. Eject the ISO and boot the disk. Reconnect using the same hostname, tailnet IP and SSH fingerprint.

If installation stops before poweroff, check `journalctl -u install-bootstrap` on the live system. Use each personalized ISO for one host.

## Flash a disk or SD card

Substitute one of these outputs in the same build command:

| Output                          | Target            |
| ------------------------------- | ----------------- |
| `packages.x86_64-linux.raw-efi` | UEFI server disk  |
| `packages.aarch64-linux.rpi4`   | Raspberry Pi 4 SD |
| `packages.aarch64-linux.rpi5`   | Raspberry Pi 5 SD |

Flash the image and power on. The node generates its own SSH host keys and joins Tailscale. Pi 4 includes the [low-write profile](../profiles/sd-card.nix). Import it in the permanent host configuration to keep those settings.
