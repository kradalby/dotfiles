{
  config,
  lib,
  ...
}:
let
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

  services.openssh = {
    enable = true;
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

  services.tailscale.enable = true;
  services.tailscale.extraSetFlags = [ "--ssh=true" ];
  systemd.services.tailscaled-autoconnect = lib.mkIf (config.services.tailscale.authKeyFile != null) {
    serviceConfig.Restart = "on-failure";
    serviceConfig.RestartSec = "15s";
  };
}
