{
  config,
  pkgs,
  lib,
  ...
}: let
  sshKeys = import ../../metadata/ssh.nix;
  port = 5000;
in {
  imports = [
    ../../common
    ../../common/incus-vm-ldn.nix
    ../../common/tailscale.nix
  ];

  networking = {
    hostName = "nix-cache";
    interfaces."${config.my.lan}" = {
      useDHCP = false;
      ipv4.addresses = [
        {
          address = "10.65.0.29";
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

  age.secrets.harmonia-signing-key = {
    file = ../../secrets/harmonia-signing-key.age;
  };

  services.harmonia = {
    enable = true;
    signKeyPaths = [config.age.secrets.harmonia-signing-key.path];
    settings = {
      bind = "[::]:${toString port}";
    };
  };

  services.tailscale.services."svc:nix-cache" = {
    endpoints."tcp:80" = "http://localhost:${toString port}";
  };

  # Relaxed GC - keep cached paths for 20 days
  nix.gc = {
    automatic = true;
    dates = lib.mkForce "weekly";
    options = lib.mkForce "--delete-older-than 20d";
  };
}
