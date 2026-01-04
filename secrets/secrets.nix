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
    eye-ldn = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDe2WAzC0HAlgMN3l2D6xjVme/mwYTVCJSq+0V1HCbAW";
    lenovo-ldn = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJTZ76SNK6QJ2ptArkXstRNOdY1PxNHHon9gh3k+fDo+";
    storage-ldn = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO9UALifE1IUfQCAxPj2GIY3QwKcGgW8IFGag8dKOc46";

    core-oracldn = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGEe9eIMf462ZQhE8Nl9jyUscRtTTYeAIPRN2kvO3cdC";

    dev-oracfurt = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE65s/hRn34v5UNhSIC8/JN/452hLdqn131gVqqBTPnl";

    # NTNU hosts
    core-ntnu = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICXhYsZfTX/h7v9eDo3vmtoTtKH1GkXhwf6uVnpi+Fj7";

    # Oracle London hosts
    headscale-oracldn = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEktSTKX3EnWnU4oi/VaBenvd8DYM8tYFjZ6qm27JDU3";

    # Storage at bassan
    # storage-bassan = "";

    # Tjoda hosts
    core-tjoda = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBSqEhLLds8shw8HMOSpN8UMBFjLPTCyg1TjHKqXvm1W";
  };

  global = (attrValues users) ++ (attrValues hosts);
  u = attrValues users;

in
with builtins;
{
  # Global secrets
  "cloudflare-token.age".publicKeys = global;
  "cloudflare-ddns-token.age".publicKeys = global;
  "discord-systemd-webhook.age".publicKeys = global;
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

  # Wireguard
  "wireguard-ldn.age".publicKeys = u ++ [
    hosts.core-ldn
    hosts.dev-ldn
  ];
  "wireguard-ntnu.age".publicKeys = u ++ [ hosts.core-ntnu ];
  "wireguard-oracldn.age".publicKeys = u ++ [ hosts.core-oracldn ];
  "wireguard-oracfurt.age".publicKeys = u ++ [ hosts.dev-oracfurt ];
  "wireguard-terra.age".publicKeys = u ++ [ hosts.core-terra ];
  "wireguard-tjoda.age".publicKeys = u ++ [ hosts.core-tjoda ];
  "wireguard-headscale-oracldn.age".publicKeys = u ++ [ hosts.headscale-oracldn ];
  # "wireguard-storage-bassan.age".publicKeys = u ++ [ hosts.storage-bassan ];

  # Unifi
  "unifi-tjoda-read-only.age".publicKeys = u ++ [ hosts.core-tjoda ];

  # headscale
  "headscale-private-key.age".publicKeys = u ++ [ hosts.core-oracldn ];
  "headscale-noise-private-key.age".publicKeys = u ++ [ hosts.core-oracldn ];
  "headscale-envfile.age".publicKeys = u ++ [ hosts.core-oracldn ];

  "matterbridge-config.age".publicKeys = u ++ [ hosts.headscale-oracldn ];

  # Grafana
  "grafana-admin.age".publicKeys = u ++ [ hosts.core-oracldn ];
  "grafana-admin-polar.age".publicKeys = u ++ [ hosts.core-terra ];

  "alertmanager-env.age".publicKeys = u ++ [ hosts.core-oracldn ];

  # Step CA
  "step-ca-password.age".publicKeys = u ++ [ hosts.core-oracldn ];
  "step-ca-config.age".publicKeys = u ++ [ hosts.core-oracldn ];

  # Nextcloud
  "nextcloud.age".publicKeys = u ++ [ hosts.core-oracldn ];

  # minio
  "minio-oracldn.age".publicKeys = u ++ [
    hosts.core-oracldn
    hosts.core-tjoda
  ];

  # Postgres
  "postgres-keycloak.age".publicKeys = u ++ [ hosts.core-oracldn ];

  # litestream
  "litestream.age".publicKeys = u ++ [
    hosts.core-oracldn
    hosts.headscale-oracldn
  ];

  # rustdesk relay
  "rustdesk-ed25519.age".publicKeys = u ++ [ hosts.core-oracldn ];
  "rustdesk-ed25519-pub.age".publicKeys = u ++ [ hosts.core-oracldn ];

  # github
  "github-headscale-token.age".publicKeys = u ++ [ hosts.lenovo-ldn ];

  # hugin
  "hugin-basicauth.age".publicKeys = u ++ [ hosts.core-terra ];
  "hugin-tokens.age".publicKeys = u ++ [ hosts.core-terra ];

  # immich
  "immich-env.age".publicKeys = u ++ [ hosts.core-terra ];
  "immich-db-password.age".publicKeys = u ++ [ hosts.core-terra ];

  # golink
  "golink-tskey.age".publicKeys = u ++ [ hosts.core-oracldn ];

  # ghostfolio
  "ghostfolio-env.age".publicKeys = u ++ [ hosts.core-oracldn ];

  # attic
  "attic-env.age".publicKeys = u ++ [ hosts.dev-oracfurt ];

  # hvor
  "hvor-tskey.age".publicKeys = u ++ [ hosts.core-oracldn ];
  "hvor-env.age".publicKeys = u ++ [ hosts.core-oracldn ];

  # krapage
  "krapage-tskey.age".publicKeys = u ++ [ hosts.core-oracldn ];
  "krapage-env.age".publicKeys = u ++ [ hosts.core-oracldn ];

  # WIFI
  "ldn-wifi.age".publicKeys = u ++ [
    hosts.dev-ldn
    hosts.eye-ldn
  ];
  "kphone15-wifi.age".publicKeys = u ++ [
    hosts.core-ldn
    hosts.dev-ldn
  ];

  # nefit-homekit
  "nefit-homekit-env.age".publicKeys = u ++ [ hosts.home-ldn ];

  # Pre authenticated keys for joining my tailscale/headscale network
  # this file is only used upon joining and will contain an expired key,
  # or a key that can only be used once.
  "tailscale-preauthkey.age".publicKeys = global;
  "headscale-client-preauthkey.age".publicKeys = global;
  "headscale-sfiber-client-preauthkey.age".publicKeys = global;

  # monica
  "monica-app-key.age".publicKeys = u ++ [ hosts.core-oracldn ];
}
