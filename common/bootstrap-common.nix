{
  config,
  lib,
  pkgs,
  ...
}:
let
  join = config.age.secrets.tailscale-preauthkey or null;
  sshKeys = import ../metadata/ssh.nix;
in
{
  system.stateVersion = lib.mkDefault lib.trivial.release;
  boot.zfs.forceImportRoot = lib.mkDefault false;
  networking.useNetworkd = lib.mkDefault true;
  networking.useDHCP = lib.mkDefault true;
  systemd.network.networks."40-wlan" =
    lib.mkIf (config.networking.wireless.enable && config.networking.useDHCP)
      {
        matchConfig.Name = "wl*";
        networkConfig.DHCP = "yes";
        dhcpV4Config.RouteMetric = 2048;
      };

  # With userborn, agenix decrypts at boot, after the image has its host identity.
  services.userborn.enable = true;
  systemd.services.agenix-install-secrets = lib.mkIf (config.age.secrets != { }) {
    before = [ "sysinit.target" ];
  };

  services.openssh = {
    enable = true;
    openFirewall = lib.mkDefault false;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 22 ];
  users.users.root.openssh.authorizedKeys.keys = sshKeys.main;
  users.users.kradalby = {
    isNormalUser = true;
    uid = 21000;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = sshKeys.main ++ sshKeys.kradalby;
  };

  services.tailscale = {
    enable = true;
    # The upstream unit reads this file into argv. Pass the CLI a file reference.
    authKeyFile = lib.mkIf (join != null) (pkgs.writeText "join-key-path" "file:${join.path}");
    extraUpFlags = [ "--ssh" ];
  };
  systemd.services.tailscaled-autoconnect = lib.mkIf (join != null) {
    serviceConfig.Restart = "on-failure";
    serviceConfig.RestartSec = "15s";
  };
}
