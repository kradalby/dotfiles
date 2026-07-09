{
  config,
  pkgs,
  lib,
  ...
}: let
  sshKeys = import ../../metadata/ssh.nix;
in {
  imports = [
    ../../common/base.nix
    ../../common/incus-vm-ldn.nix
    ../../common/systemd-exporter.nix
    ../../common/tailscale.nix
  ];

  networking = {
    hostName = "ts1p";
    hostId = "5e7ec0de";
    interfaces."${config.my.lan}" = {
      useDHCP = false;
      ipv4.addresses = [
        {
          address = "10.65.0.30";
          prefixLength = 24;
        }
      ];
      ipv4.routes = [
        {
          address = "10.65.0.1";
          prefixLength = 32;
        }
      ];
    };
  };

  users.users.root.openssh.authorizedKeys.keys = sshKeys.main ++ sshKeys.kradalby ++ sshKeys.work;
  users.users.kradalby.openssh.authorizedKeys.keys = sshKeys.main ++ sshKeys.kradalby ++ sshKeys.work;

  # setec-compatible secrets server backed by 1Password. Registers on the
  # tailnet as "setec" (the host itself is "ts1p"). The OP service-account
  # token — and optionally TS_AUTHKEY for unattended tailnet enrolment — live
  # in the agenix EnvironmentFile below as a placeholder; set the real values
  # with `ragenix -e ts1p-op-token.age`, then redeploy.
  age.secrets.ts1p-op-token.file = ../../secrets/ts1p-op-token.age;
  services.ts1p = {
    enable = true;
    hostname = "setec";
    vault = "ts1p";
    environmentFile = config.age.secrets.ts1p-op-token.path;
    # Cache reads ~24h (jittered ±20%): secrets rarely rotate, and a long TTL
    # keeps cold reads — which serialize behind the op WASM mutex — rare. After
    # rotating a secret, flush via /debug/flush-cache or a Cache-Control:
    # no-cache request.
    cacheExpiry = "24h";
    # Proactively recycle the 1Password WASM core every 6h to stay ahead of its
    # corruption-under-uptime (kradalby/ts1p#2); exits 0, systemd restarts it.
    opMaxAge = "6h";
  };

  # op CLI for the 1Password service account (token provisioned separately).
  environment.systemPackages = [pkgs._1password-cli];

  # Reach node (9100) and systemd (9558) exporters over the tailnet. The host
  # joins the tailscale.com tailnet as node "ts1p-ldn" (separate from the "setec"
  # tsnet listener), and tailscale0 is not a trusted interface here, so open the
  # exporter ports on it explicitly. node-exporter only opens on my.lan (enp5s0)
  # and systemd-exporter opens globally, but we pin both to tailscale0 to make the
  # scrape path intentional.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    config.services.prometheus.exporters.node.port
    config.services.prometheus.exporters.systemd.port
  ];

  # ts1p lives only on the tailscale.com tailnet (as setec.dalby.ts.net).
  # common/tailscale.nix also wires a secondary headscale.kradalby.no instance;
  # ts1p has no business there, and its failing autoconnect breaks deploys.
  services.tailscales.headscale.enable = lib.mkForce false;
}
