with builtins;
let
  users = {
    kradalby = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBV4ZjlUvRDs70qHD/Ldi6OTkFpDEFgfbXbqSnaL2Qup";
  };

  hosts = {
    # Terra hosts
    dev-terra = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMWqiendEfZNjhaXu0RTrNUPcNeRJKeiu2pZ+mjAWWsM";

    k3m1-terra = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINAY5rkpRN5U2ApZGQPPr6E9Mx1NVrI8EdUDUZFRLlKW";
    k3a1-terra = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAeWP0sz11ZibeRmJsIbLgFLK/rUmia0KcXGlZKbnycp";
    k3a2-terra = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO1YyxAf57LjkvULrmgBAP91D/BoRtD15KWjIbfW8XrY";

    # London hosts
    core-ldn = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINRxkYxhNbI3+SGbm1ecm+r6PYAtJLDCvKv5F7midx7K";
    home-ldn = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINSfUa0k5lySBwBhx2BfovlKhpkCBCgY5BkzagPJNVhd";


    core-oracldn = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGEe9eIMf462ZQhE8Nl9jyUscRtTTYeAIPRN2kvO3cdC";

    # NTNU hosts
    core-ntnu = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICXhYsZfTX/h7v9eDo3vmtoTtKH1GkXhwf6uVnpi+Fj7";

    # Oracle London hosts
    headscale-oracldn = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN2wiCW3z5MpNw7sVrs2ot2uThEdM0LlCJCr/IJRXlty";
  };

  global = (attrValues users) ++ (attrValues hosts);
  u = attrValues users;

  k3s-terra = [
    hosts.k3m1-terra
    hosts.k3a1-terra
    hosts.k3a2-terra
  ];
in
with builtins;
{
  # Global secrets
  "cloudflare-token.age".publicKeys = global;
  "cloudflare-ddns-token.age".publicKeys = global;
  "discord-systemd-webhook.age".publicKeys = global;
  "r.age".publicKeys = global;

  # Restic
  "restic-home-ldn-token.age".publicKeys = u ++ [ hosts.home-ldn ];
  "restic-headscale-oracldn-token.age".publicKeys = u ++ [ hosts.headscale-oracldn ];
  "restic-core-oracldn-token.age".publicKeys = u ++ [ hosts.core-oracldn ];
  "restic-kramacbook-token.age".publicKeys = u;

  # Wireguard
  "wireguard-ldn.age".publicKeys = u ++ [ hosts.core-ldn ];
  "wireguard-ntnu.age".publicKeys = u ++ [ hosts.core-ntnu ];
  "wireguard-oracldn.age".publicKeys = u ++ [ hosts.core-oracldn ];
  "wireguard-terra.age".publicKeys = u; # ++ [ hosts.core-terra ];
  "wireguard-tjoda.age".publicKeys = u; # ++ [ hosts.core-tjoda ];
  "wireguard-headscale-oracldn.age".publicKeys = u ++ [ hosts.headscale-oracldn ];

  # Unifi
  "unifi-ldn-read-only.age".publicKeys = u ++ [ hosts.home-ldn ];

  # headscale
  "headscale-private-key.age".publicKeys = u ++ [ hosts.headscale-oracldn ];
  "headscale-oidc-secret.age".publicKeys = u ++ [ hosts.headscale-oracldn ];
  "matterbridge-config.age".publicKeys = u ++ [ hosts.headscale-oracldn ];

  # k3s
  "k3s-terra.age".publicKeys = u ++ k3s-terra;
}
