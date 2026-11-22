#!/usr/bin/env bash
set -eu
if ! mountpoint -q /mnt || ! mountpoint -q /mnt/boot; then
  echo 'Mount the target root and EFI partition first.' >&2
  exit 1
fi
if test -e /mnt/var/lib/tailscale/tailscaled.state; then
  echo 'Target already has a Tailscale identity.' >&2
  exit 1
fi

# Preserve the fingerprint already trusted by the SSH client.
install -d -m 0700 /mnt/etc/ssh
for key in /etc/ssh/ssh_host_*_key; do
  target=/mnt$key
  test ! -e "$target" || cmp -s "$key" "$target" || {
    echo "Different host key at $target" >&2
    exit 1
  }
  install -m 0600 "$key" "$target"
  install -m 0644 "$key.pub" "$target.pub"
done

nixos-install --substituters "" --no-channel-copy --no-root-passwd \
  --root /mnt --system "$TARGET_SYSTEM"

# A system service survives the SSH disconnect while tailscaled is stopped.
install -d /mnt/var/lib
staging=$(mktemp -d /mnt/var/lib/.tailscale.XXXXXX)
trap 'rm -rf "$staging"; systemctl start --no-block tailscaled' EXIT
systemctl stop tailscaled
cp -a /var/lib/tailscale/. "$staging/"
mv -T "$staging" /mnt/var/lib/tailscale
sync -f /mnt
systemctl --no-block poweroff
trap - EXIT
