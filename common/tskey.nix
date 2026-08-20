{ ... }: {
  # Fleet host-join key. Root-only (tailscaled joins as root); the default
  # agenix mode is 0400 root, so no mode override — it must never be
  # world-readable. One-time and minted on demand; see
  # docs/conventions/secrets.md. Every service carries its own key except the
  # grafana tailscale-proxy (root LoadCredential) — give it its own key at the
  # next rotation.
  age.secrets.tailscale-preauthkey.file = ../secrets/tailscale-preauthkey.age;
}
