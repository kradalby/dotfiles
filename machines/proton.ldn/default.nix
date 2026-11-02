{
  config,
  pkgs,
  ...
}:
let
  sshKeys = import ../../metadata/ssh.nix;
  bridgePasswordCommand = "${pkgs.gnused}/bin/sed -n 's/^PROTON_IMAP_PASSWORD=//p' ${config.age.secrets.proton-imap-check.path}";
in
{
  imports = [
    ../../common/base.nix
    ../../common/incus-vm-ldn.nix
    ../../common/systemd-exporter.nix
    ../../common/tailscale.nix

    ./proton.nix
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

    home.packages = [
      pkgs.unstable.himalaya

      # Headless: no secret-service keyring, so hand pm-cli the bridge
      # password through its env override instead.
      (pkgs.writeShellScriptBin "pm-cli" ''
        PM_CLI_BRIDGE_PASSWORD=$(${bridgePasswordCommand}) \
          exec ${pkgs.pm-cli}/bin/pm-cli "$@"
      '')
    ];

    # The pinned Home Manager account generator uses the pre-v2 schema.
    # Verify with `himalaya account check` and `himalaya mailbox list`.
    xdg.configFile."himalaya/config.toml".source =
      (pkgs.formats.toml { }).generate "himalaya-config.toml"
        {
          accounts.proton = {
            default = true;
            email = "kristoffer@dalby.cc";
            display-name = "Kristoffer Dalby";
            imap = {
              server = "imap://127.0.0.1:1143";
              sasl.plain = {
                username = "kristoffer@dalby.cc";
                password.command = bridgePasswordCommand;
              };
            };
            smtp = {
              server = "smtp://127.0.0.1:1025";
              sasl.plain = {
                username = "kristoffer@dalby.cc";
                password.command = bridgePasswordCommand;
              };
            };
          };
        };

    xdg.configFile."pm-cli/config.yaml".text = builtins.toJSON {
      bridge = {
        imap_host = "127.0.0.1";
        imap_port = 1143;
        smtp_host = "127.0.0.1";
        smtp_port = 1025;
        email = "kristoffer@dalby.cc";
      };
    };
  };

  system.stateVersion = "26.05";
}
