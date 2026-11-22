# Build a host image

Copy a profile into a directory outside the checkout, set its hostname, and build with `nix build`. The `image-config` input is an ordinary NixOS module. Its settings apply to the installed OS. The installer stays offline from Tailscale throughout installation.

| Profile                                                  | Edit                                         |
| -------------------------------------------------------- | -------------------------------------------- |
| [Wired DHCP](../images/examples/wired/default.nix)       | Hostname                                     |
| [Wi-Fi with DHCP](../images/examples/wifi/default.nix)   | Hostname and encrypted Wi-Fi network block   |
| [Static Ethernet](../images/examples/static/default.nix) | Hostname, MAC, address/prefix, route and DNS |

## Prepare the host module

Run from the repo root. This example creates a **new** host identity. For a reinstall, use the host's existing Ed25519 identity and its public key. The build input directory must contain only Nix code and ciphertext: Nix copies the entire directory into the store. Keep private keys and plaintext inputs elsewhere.

```sh
set -o pipefail
umask 077
work=$(mktemp -d)
mkdir "$work/config"
cp images/examples/wired/default.nix "$work/config/"
ssh-keygen -q -t ed25519 -N '' -f "$work/ssh_host_ed25519_key"
authkey kradalby | age -R "$work/ssh_host_ed25519_key.pub" -o "$work/config/join.age"
```

Use `age` from `nix shell nixpkgs#age` if needed. `authkey kradalby` issues a single-use key valid for 24 hours by default. If shipping the device, choose an expiry that covers its first online boot.

For Wi-Fi, start from `images/examples/wifi/default.nix`. Put the SSID and password together in a private wpa_supplicant file outside `config/`:

```conf
network={
    ssid="Cabin Wi-Fi"
    psk="your-passphrase"
}
```

Encrypt that file for the target:

```sh
age -R "$work/ssh_host_ed25519_key.pub" \
  -o "$work/config/wifi.age" /path/to/private/wifi.conf
```

## One installer ISO

To carry the host's identity on the **same ISO**, wrap it with a passphrase before building. The live console will ask for that passphrase when you restore the identity to the target disk.

```sh
age -p -o "$work/config/installer-identity.age" "$work/ssh_host_ed25519_key"
nix build .#installer-iso --override-input image-config "path:$work/config"
ls result/iso/
```

Boot the ISO in UEFI mode. At its console, prepare and mount the chosen destination disk. The default target expects an ext4 root labeled `nixos` at `/mnt` and a FAT EFI system partition labeled `ESP` at `/mnt/boot`. Check both mounts before installing. As root on a **fresh target**, run:

```sh
mountpoint -q /mnt && mountpoint -q /mnt/boot || exit 1
install -d -m 0700 /mnt/etc/ssh
key=/mnt/etc/ssh/ssh_host_ed25519_key
test ! -e "$key" || exit 1
umask 077
age -d -o "$key.new" /iso/provision/installer-identity.age &&
  ssh-keygen -y -f "$key.new" > "$key.pub" &&
  mv "$key.new" "$key" || exit 1
nixos-install --no-channel-copy --no-root-passwd --root /mnt --system "$(cat /iso/provision/target-system)"
```

If the target already has the matching identity, skip key creation and decryption. Eject the ISO and boot from disk. Ragenix decrypts the join key, networking comes up, and the installed machine joins Tailscale. The node keeps its identity in `/var/lib/tailscale` on subsequent boots. Use `ssh root@HOSTNAME` from an authorized peer. With MagicDNS disabled, use the Tailscale IP.

## Flash directly to disk or SD

Choose the output for the target. The Pi builds require an aarch64 Linux builder or configured emulation. An x86-64 Linux builder produces the server images.

```sh
nix build .#packages.aarch64-linux.rpi4 --override-input image-config "path:$work/config"
nix build .#packages.aarch64-linux.rpi5 --override-input image-config "path:$work/config"
nix build .#packages.x86_64-linux.raw-efi --override-input image-config "path:$work/config"
```

Flash the selected image. Before first boot, mount the flashed **root** filesystem. For a fresh device, install its matching identity there, substituting the actual mount point:

```sh
mountpoint -q /mnt || exit 1
sudo install -d -m 0700 /mnt/etc/ssh
sudo test ! -e /mnt/etc/ssh/ssh_host_ed25519_key || exit 1
sudo install -m 0600 "$work/ssh_host_ed25519_key" /mnt/etc/ssh/
sudo install -m 0644 "$work/ssh_host_ed25519_key.pub" /mnt/etc/ssh/
sudo umount /mnt
```

The Pi needs only that card at power-on. Preserve the matching identity when deploying the permanent fleet configuration. Pi 4 images include volatile journals, RAM-backed temporary files and zram. Add `imports = [ ../../profiles/sd-card.nix ];` in the permanent machine module to keep those settings after the first fleet deployment. See the [SD-card profile](../profiles/sd-card.nix) and [bench checks](../profiles/pi4-sd.md#bench-acceptance-before-remote-placement).

A build without an override produces an unpersonalized image with wired DHCP and key-only OpenSSH access on the LAN. Personalized examples restrict SSH to the tailnet. The old `BOOTSTRAP_*` environment variables have been replaced by encrypted module inputs.
