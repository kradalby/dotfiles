with builtins;
let
  users = {
    kradalby = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBV4ZjlUvRDs70qHD/Ldi6OTkFpDEFgfbXbqSnaL2Qup";
  };

  hosts = {
    # Terra hosts
    dev-terra = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMWqiendEfZNjhaXu0RTrNUPcNeRJKeiu2pZ+mjAWWsM";

    k3m1-terra = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIfHBW3Uhtr3GXgIx2y1BhmAhJtm5GryohVAxRhQ2PSM";
    k3a1-terra = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK/l5lbDOQliAixJPyWf1uz0OA8V/yjki8cCD2bFHvJ5";
    k3a2-terra = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILtIfcosxFY04DnvptOmkXK3OiHjYxWjyvjU3V4khqHs";

    # London hosts
    core-ldn = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINRxkYxhNbI3+SGbm1ecm+r6PYAtJLDCvKv5F7midx7K";
    home-ldn = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINSfUa0k5lySBwBhx2BfovlKhpkCBCgY5BkzagPJNVhd";

    # NTNU hosts
    core-ntnu = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICXhYsZfTX/h7v9eDo3vmtoTtKH1GkXhwf6uVnpi+Fj7";

    # Oracle London hosts
    headscale-oracldn = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN2wiCW3z5MpNw7sVrs2ot2uThEdM0LlCJCr/IJRXlty";
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

  # Restic
  "restic-home-ldn-token.age".publicKeys = u ++ [ hosts.home-ldn ];
  "restic-headscale-oracldn-token.age".publicKeys = u ++ [ hosts.headscale-oracldn ];
  "restic-kramacbook-token.age".publicKeys = u;

  # Wireguard
  "wireguard-ldn.age".publicKeys = u ++ [ hosts.core-ldn ];
  "wireguard-ntnu.age".publicKeys = u ++ [ hosts.core-ntnu ];
  "wireguard-oracldn.age".publicKeys = u; # ++ [ hosts.core.oracldn ];
  "wireguard-terra.age".publicKeys = u; # ++ [ hosts.core-terra ];
  "wireguard-tjoda.age".publicKeys = u; # ++ [ hosts.core-tjoda ];
  "wireguard-headscale-oracldn.age".publicKeys = u ++ [ hosts.headscale-oracldn ];

  # Unifi
  "unifi-ldn-read-only.age".publicKeys = u ++ [ hosts.home-ldn ];

  # headscale
  "headscale-private-key.age".publicKeys = u ++ [ hosts.headscale-oracldn ];
  "headscale-oidc-secret.age".publicKeys = u ++ [ hosts.headscale-oracldn ];
}
