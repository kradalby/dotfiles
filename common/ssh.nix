{ config, lib, ... }:
{
  services.openssh = {
    enable = true;
    openFirewall = true;

  };

  systemd.services.sshd.onFailure = [ "notify-email@%n.service" ];
}
