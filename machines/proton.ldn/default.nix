{
  config,
  pkgs,
  ...
}:
let
  sshKeys = import ../../metadata/ssh.nix;
in
{
  imports = [
    ../../common/base.nix
    ../../common/incus-vm-ldn.nix
    ../../common/systemd-exporter.nix
    ../../common/tailscale.nix
  ];

  networking = {
    hostName = "proton";
    interfaces."${config.my.lan}" = {
      useDHCP = false;
      ipv4.addresses = [
        {
          address = "10.65.0.31";
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

  # The bridge alone nearly fills this small guest, and nix receiving a deploy
  # closure gets OOM-killed with only the incus zram, which is sized off RAM.
  swapDevices = [
    {
      device = "/swapfile";
      size = 2048;
    }
  ];

  # tailscale0 is not trusted here; open the exporters for the tailnet scrape.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    config.services.prometheus.exporters.node.port
    config.services.prometheus.exporters.systemd.port
  ];

  # Mail-triage agents only: no toolchains on a box nobody develops on.
  home-manager.users.kradalby = {
    my.packages = {
      go.enable = false;
      web.enable = false;
      python.enable = false;
      infra.enable = false;
      media.enable = false;
      ai.opencode = false;
      ai.codex = true;
    };
  };

  system.stateVersion = "26.05";
}
