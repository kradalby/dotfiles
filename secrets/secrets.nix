with builtins;
let
  users = {
    kradalby = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBV4ZjlUvRDs70qHD/Ldi6OTkFpDEFgfbXbqSnaL2Qup";
    kratail = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJjAKM+WX/sNJwMcgOv87DXfeXD/fGG7RyCF8svQNbLL";
    kraairm2 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH9CaLKIYSLK4qvaWDcqFZOTdI+oPSN+dOA1u531sJG9";
  };

  hosts = {
    # Terra hosts
    core-terra = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGEzxjps58aIrw1ZxgDUuj1W7T3Bx6ZbO6Q34a0xj2BA";
    dev-terra = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMWqiendEfZNjhaXu0RTrNUPcNeRJKeiu2pZ+mjAWWsM";

    # Leiden hosts
    core-ldn = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICRRxykpKi6wemG1DPI+9gpWtbGQWGP1D5xb6oATreAv";
    home-ldn = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHfmOgoC9GlB9r1lTBEnDp6YO8/FDgGRMEAv+A9sB7de";
    dev-ldn = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHNrRieVfrCvnqNbuxEr06c6D1/lhGlEIvS8NNQhrmJt";
    lenovo-ldn = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJTZ76SNK6QJ2ptArkXstRNOdY1PxNHHon9gh3k+fDo+";
    storage-ldn = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICj6c1im2tC/E1ZYlFtryyqNui58+onflUqBiVOuc1on";
    rpi5-ldn = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHCZ2YG1xvb9BJjYbv9MWWeqhjCNzZROWkwaPQFM76/T";
    ts1p-ldn = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHXka6MsWIgSNxAyhdILZ7+hWbR4CvWgKdBCVQWQM/MV";

    core-oracldn = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGEe9eIMf462ZQhE8Nl9jyUscRtTTYeAIPRN2kvO3cdC";

    dev-oracfurt = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE65s/hRn34v5UNhSIC8/JN/452hLdqn131gVqqBTPnl";

    # Oracle London hosts
    headscale-oracldn = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEktSTKX3EnWnU4oi/VaBenvd8DYM8tYFjZ6qm27JDU3";

    # Storage at bassan
    # storage-bassan = "";

    # Tjoda hosts
    core-tjoda = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBSqEhLLds8shw8HMOSpN8UMBFjLPTCyg1TjHKqXvm1W";

    # Bare-metal builder + tsnixcache + incus host
    gigabuilder = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIfxql6LaBrlxvBDywHRWULRocO9Yo57DlrlsdDCkcis";

    # garnix CI VM (Incus guest on gigabuilder)
    garnix = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH4QDcKi9nGekv41QHPMC8Wv+FfQ6PCE1vrvA0an9SxW";
  };

  global = (attrValues users) ++ (attrValues hosts);
  u = attrValues users;
in
with builtins;
{
  # Global secrets. NOTE cloudflare-token is a zone-edit token that public-facing
  # gigabuilder can now decrypt (for DNS-01 ACME) — accepted; scope it or move
  # gigabuilder to HTTP-01 if the blast radius ever matters.
  "cloudflare-token.age".publicKeys = global;
  "cloudflare-ddns-token.age".publicKeys = global;
  "r.age".publicKeys = global;
  "ca.age".publicKeys = global;

  # Restic
  "restic-home-ldn-token.age".publicKeys = u ++ [ hosts.home-ldn ];
  "restic-headscale-oracldn-token.age".publicKeys = u ++ [ hosts.headscale-oracldn ];
  "restic-core-oracldn-token.age".publicKeys = u ++ [ hosts.core-oracldn ];
  "restic-dev-oracfurt-token.age".publicKeys = u ++ [ hosts.dev-oracfurt ];
  "restic-dev-ldn-token.age".publicKeys = u ++ [ hosts.dev-ldn ];
  "restic-core-tjoda-token.age".publicKeys = u ++ [ hosts.core-tjoda ];
  "restic-storage-ldn-token.age".publicKeys = u ++ [ hosts.storage-ldn ];
  "restic-core-terra-token.age".publicKeys = u ++ [ hosts.core-terra ];
  "restic-kramacbook-token.age".publicKeys = u;
  "restic-kraairm2-token.age".publicKeys = u;
  "restic-kratail-token.age".publicKeys = u;

  # Unifi
  "unifi-tjoda-read-only.age".publicKeys = u ++ [ hosts.core-tjoda ];

  # headscale
  "headscale-private-key.age".publicKeys = u ++ [ hosts.core-oracldn ];
  "headscale-noise-private-key.age".publicKeys = u ++ [ hosts.core-oracldn ];
  "headscale-envfile.age".publicKeys = u ++ [ hosts.core-oracldn ];

  # Grafana
  "grafana-admin.age".publicKeys = u ++ [ hosts.core-oracldn ];

  "alertmanager-env.age".publicKeys = u ++ [ hosts.core-oracldn ];

  "oci-usage-exporter.age".publicKeys = u ++ [ hosts.core-oracldn ];

  # bridge IMAP credentials for the authenticated login probe (a signed-out
  # bridge keeps listening; only a LOGIN proves it works)
  "proton-imap-check.age".publicKeys = u ++ [ hosts.dev-oracfurt ];

  # garage (RPC secret + admin token; token also in setec for the
  # infrastructure garage/ tofu root)
  "garage.age".publicKeys = u ++ [ hosts.core-tjoda ];

  # minio
  "minio-oracldn.age".publicKeys = u ++ [
    hosts.core-oracldn
    hosts.core-tjoda
  ];

  # litestream (per-host garage keys; also in setec under
  # infra/garage/tjoda/litestream-<host>/ for the tofu grants)
  "litestream-oracldn.age".publicKeys = u ++ [ hosts.core-oracldn ];
  "litestream-oracfurt.age".publicKeys = u ++ [ hosts.dev-oracfurt ];

  # hugin
  "hugin-basicauth.age".publicKeys = u ++ [ hosts.core-terra ];
  "hugin-tokens.age".publicKeys = u ++ [ hosts.core-terra ];

  # golink
  "golink-tskey.age".publicKeys = u ++ [ hosts.core-oracldn ];

  # hvor
  "hvor-tskey.age".publicKeys = u ++ [ hosts.core-oracldn ];
  "hvor-env.age".publicKeys = u ++ [ hosts.core-oracldn ];

  # krapage
  "krapage-tskey.age".publicKeys = u ++ [ hosts.core-oracldn ];
  "krapage-env.age".publicKeys = u ++ [ hosts.core-oracldn ];

  # WIFI
  "ldn-wifi.age".publicKeys = u ++ [
    hosts.dev-ldn
    hosts.rpi5-ldn
  ];
  "kphone15-wifi.age".publicKeys = u ++ [
    hosts.core-ldn
    hosts.dev-ldn
  ];

  # nefit-homekit
  "nefit-homekit-env.age".publicKeys = u ++ [ hosts.home-ldn ];

  # ts1p (setec) — OP_SERVICE_ACCOUNT_TOKEN (+ optional TS_AUTHKEY) EnvironmentFile
  "ts1p-op-token.age".publicKeys = u ++ [ hosts.ts1p-ldn ];

  # Pre authenticated keys for joining my tailscale/headscale network
  # this file is only used upon joining and will contain an expired key,
  # or a key that can only be used once.
  "tailscale-preauthkey.age".publicKeys = global;
  "headscale-client-preauthkey.age".publicKeys = global;
  "headscale-sfiber-client-preauthkey.age".publicKeys = global;

  # tsnixcache (gigabuilder serves the binary cache); the tsnet nodes reuse the
  # host's reusable join keys, so only the signing key is cache-specific.
  "tsnixcache-sign-key.age".publicKeys = u ++ [ hosts.gigabuilder ];

  # sfiber tailnet membership for the garnix VM (tag:ci, forced by the
  # key): build-success pokes to the sfiber deployd hosts.
  "headscale-sfiber-ci-preauthkey.age".publicKeys = u ++ [ hosts.garnix ];

  # garnix CI (decrypted on the garnix VM)
  "garnix-database-password.age".publicKeys = u ++ [ hosts.garnix ];
  "garnix-jwt-key.age".publicKeys = u ++ [ hosts.garnix ];
  "garnix-opensearch-credential.age".publicKeys = u ++ [ hosts.garnix ];
  "garnix-repo-secrets-key.age".publicKeys = u ++ [ hosts.garnix ];
  "garnix-repo-secrets-key-pub.age".publicKeys = u ++ [ hosts.garnix ];
  "garnix-action-runner-ssh.age".publicKeys = u ++ [ hosts.garnix ];
  "garnix-remote-builder-ssh.age".publicKeys = u ++ [ hosts.garnix ];
  "garnix-github-app-id.age".publicKeys = u ++ [ hosts.garnix ];
  "garnix-github-app-pk.age".publicKeys = u ++ [ hosts.garnix ];
  "garnix-github-client-id.age".publicKeys = u ++ [ hosts.garnix ];
  "garnix-github-client-secret.age".publicKeys = u ++ [ hosts.garnix ];
  "garnix-github-webhook-secret.age".publicKeys = u ++ [ hosts.garnix ];
}
