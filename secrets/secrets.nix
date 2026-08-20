with builtins;
let
  users = {
    kradalby = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBV4ZjlUvRDs70qHD/Ldi6OTkFpDEFgfbXbqSnaL2Qup";
    kratail = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJjAKM+WX/sNJwMcgOv87DXfeXD/fGG7RyCF8svQNbLL";
    kraairm2 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH9CaLKIYSLK4qvaWDcqFZOTdI+oPSN+dOA1u531sJG9";
  };

  hosts = {
    # Leiden hosts
    core-ldn = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICRRxykpKi6wemG1DPI+9gpWtbGQWGP1D5xb6oATreAv";
    home-ldn = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHfmOgoC9GlB9r1lTBEnDp6YO8/FDgGRMEAv+A9sB7de";
    dev-ldn = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHNrRieVfrCvnqNbuxEr06c6D1/lhGlEIvS8NNQhrmJt";
    storage-bassan = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJTZ76SNK6QJ2ptArkXstRNOdY1PxNHHon9gh3k+fDo+";
    storage-ldn = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICj6c1im2tC/E1ZYlFtryyqNui58+onflUqBiVOuc1on";
    rpi5-ldn = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHCZ2YG1xvb9BJjYbv9MWWeqhjCNzZROWkwaPQFM76/T";
    ts1p-ldn = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHXka6MsWIgSNxAyhdILZ7+hWbR4CvWgKdBCVQWQM/MV";

    core-oracldn = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGEe9eIMf462ZQhE8Nl9jyUscRtTTYeAIPRN2kvO3cdC";

    dev-oracfurt = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE65s/hRn34v5UNhSIC8/JN/452hLdqn131gVqqBTPnl";

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
  # Cloudflare zone-edit token: only the DNS-01 ACME hosts (common/acme.nix).
  "cloudflare-token.age".publicKeys = u ++ [
    hosts.core-oracldn
    hosts.gigabuilder
  ];
  # DDNS token: only the hosts running common/ddns.nix.
  "cloudflare-ddns-token.age".publicKeys = u ++ [
    hosts.storage-ldn
    hosts.core-tjoda
  ];

  # Restic
  "restic-home-ldn-token.age".publicKeys = u ++ [ hosts.home-ldn ];
  "restic-core-oracldn-token.age".publicKeys = u ++ [ hosts.core-oracldn ];
  "restic-dev-oracfurt-token.age".publicKeys = u ++ [ hosts.dev-oracfurt ];
  "restic-dev-ldn-token.age".publicKeys = u ++ [ hosts.dev-ldn ];
  "restic-core-tjoda-token.age".publicKeys = u ++ [ hosts.core-tjoda ];
  "restic-storage-ldn-token.age".publicKeys = u ++ [ hosts.storage-ldn ];
  "restic-kraairm2-token.age".publicKeys = u;
  "restic-kratail-token.age".publicKeys = u;
  "restic-storage-bassan-token.age".publicKeys = u ++ [ hosts.storage-bassan ];
  "restic-gigabuilder-token.age".publicKeys = u ++ [ hosts.gigabuilder ];

  # Syncthing: shared encryption passphrase for the untrusted offsite mirror
  # (storage.bassan). Held only by the trusted senders; bassan is NOT a recipient.
  "syncthing-storage-enc.age".publicKeys = u ++ [
    hosts.storage-ldn
    hosts.core-tjoda
  ];

  # headscale
  "headscale-private-key.age".publicKeys = u ++ [ hosts.core-oracldn ];
  "headscale-noise-private-key.age".publicKeys = u ++ [ hosts.core-oracldn ];
  "headscale-envfile.age".publicKeys = u ++ [ hosts.core-oracldn ];

  # Grafana
  "grafana-admin.age".publicKeys = u ++ [ hosts.core-oracldn ];
  "grafana-secret-key.age".publicKeys = u ++ [ hosts.core-oracldn ];

  "alertmanager-env.age".publicKeys = u ++ [ hosts.core-oracldn ];

  "oci-usage-exporter.age".publicKeys = u ++ [ hosts.core-oracldn ];

  # ghdl: GHDL_GITHUB_TOKEN + TS_AUTHKEY
  "ghdl.age".publicKeys = u ++ [ hosts.core-oracldn ];

  # bridge IMAP credentials for the authenticated login probe (a signed-out
  # bridge keeps listening; only a LOGIN proves it works)
  "proton-imap-check.age".publicKeys = u ++ [ hosts.dev-oracfurt ];

  # garage (RPC secret + admin token; token also in setec for the
  # infrastructure garage/ tofu root)
  "garage.age".publicKeys = u ++ [ hosts.core-tjoda ];

  # litestream (per-host garage keys; also in setec under
  # infra/garage/tjoda/litestream-<host>/ for the tofu grants)
  "litestream-oracldn.age".publicKeys = u ++ [ hosts.core-oracldn ];
  "litestream-oracfurt.age".publicKeys = u ++ [ hosts.dev-oracfurt ];

  # golink
  "golink-tskey.age".publicKeys = u ++ [ hosts.core-oracldn ];

  # hugin
  "hugin-tskey.age".publicKeys = u ++ [ hosts.core-tjoda ];

  # hvor
  "hvor-tskey.age".publicKeys = u ++ [ hosts.core-oracldn ];
  "hvor-env.age".publicKeys = u ++ [ hosts.core-oracldn ];

  # krapage
  "krapage-tskey.age".publicKeys = u ++ [ hosts.core-oracldn ];
  # Shared by the three home.ldn homekit bridges (tag:homekit, reusable —
  # from infrastructure/tailscale authkey_homekit.tf). Root:0400; the bridges
  # read it via LoadCredential.
  "homekit-tskey.age".publicKeys = u ++ [ hosts.home-ldn ];
  # tsnixcache's kradalby-tailnet node (authkey_tsnixcache.tf); its sfiber
  # node keeps the sfiber key.
  "tsnixcache-tskey.age".publicKeys = u ++ [ hosts.gigabuilder ];
  "krapage-env.age".publicKeys = u ++ [ hosts.core-oracldn ];

  # WIFI
  "ldn-wifi.age".publicKeys = u ++ [
    hosts.dev-ldn
    hosts.rpi5-ldn
  ];

  # nefit-homekit
  "nefit-homekit-env.age".publicKeys = u ++ [ hosts.home-ldn ];

  # ts1p (setec) — OP_SERVICE_ACCOUNT_TOKEN (+ optional TS_AUTHKEY) EnvironmentFile
  "ts1p-op-token.age".publicKeys = u ++ [ hosts.ts1p-ldn ];

  # Fleet host-join key: single-use, minted on demand (authkey -reusable=false)
  # and spent the moment a host joins, so the committed copy is normally a
  # burned key. Root-only on-host (common/tskey.nix); every service carries its
  # own key (sole exception: the grafana proxy, see tskey.nix). Recipients stay
  # broad because
  # any host may need to rebuild-join, and a spent one-time key is inert.
  "tailscale-preauthkey.age".publicKeys = global;
  # sfiber tailnet join key, scoped to its consumers (gigabuilder cache,
  # dev.ldn plural instance, core.tjoda proxies; garnix has its own CI key).
  "headscale-sfiber-client-preauthkey.age".publicKeys = u ++ [
    hosts.gigabuilder
    hosts.dev-ldn
    hosts.core-tjoda
  ];

  # tsnixcache (gigabuilder serves the binary cache); its kradalby-tailnet
  # node has its own key (tsnixcache-tskey above), the sfiber node uses the
  # sfiber join key.
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
