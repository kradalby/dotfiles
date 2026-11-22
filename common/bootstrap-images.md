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
2. Run `ssh root@HOSTNAME` over Tailscale. Your tailnet policy must allow SSH to `root`. On the LAN, use `ssh root@LAN_IP` with your usual [SSH key](../metadata/ssh.nix).
3. Identify the target with `lsblk`. On a fresh disk, create a GPT with a 512 MiB EFI System partition and a Linux partition using the remaining space. For example, **if the target is `/dev/nvme0n1`**, run `cfdisk /dev/nvme0n1` to create the partitions. Formatting erases the selected partitions.

   ```sh
   mkfs.fat -F 32 -n ESP /dev/nvme0n1p1
   mkfs.ext4 -L nixos /dev/nvme0n1p2
   mount /dev/nvme0n1p2 /mnt
   mount --mkdir /dev/nvme0n1p1 /mnt/boot
   ```

4. Run `systemctl start --no-block install-bootstrap`. This repo's ISO service runs standard `nixos-install` with your prebuilt system and bootloader, copies the live SSH host keys and Tailscale state, then powers off. The service keeps running when SSH disconnects.
5. Eject the ISO, boot the disk, and reconnect with the same SSH command. The installed system is the bootstrap profile you built into the ISO.

If installation stops before poweroff, check `journalctl -u install-bootstrap` on the live system. Use each personalized ISO for one host.

## Flash a disk or SD card

Substitute one of these outputs in the same build command:

| Output                          | Target            |
| ------------------------------- | ----------------- |
| `packages.x86_64-linux.raw-efi` | UEFI server disk  |
| `packages.aarch64-linux.rpi4`   | Raspberry Pi 4 SD |
| `packages.aarch64-linux.rpi5`   | Raspberry Pi 5 SD |

Flash the image and power on. The node generates its own SSH host keys and joins Tailscale. Pi 4 includes the [low-write profile](../profiles/sd-card.nix). Import it in the permanent host configuration to keep those settings.
