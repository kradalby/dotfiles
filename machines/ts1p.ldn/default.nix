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
    tokenFile = config.age.secrets.ts1p-op-token.path;
  };

  # op CLI for the 1Password service account (token provisioned separately).
  environment.systemPackages = [pkgs._1password-cli];
}
