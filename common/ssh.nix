{ config, lib, ... }:
{
  services.openssh = {
    enable = true;
    openFirewall = true;
    passwordAuthentication = false;
  };

  # networking.firewall.interfaces."${config.my.lan}".allowedTCPPorts = config.services.openssh.ports;

  systemd.services.sshd.onFailure = [ "notify-discord@%n.service" ];
}
