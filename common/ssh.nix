{
  config,
  lib,
  ...
}:
{
  services.openssh = {
    enable = true;
    openFirewall = true;
    settings.PasswordAuthentication = false;
    # Keys + tailscale-SSH everywhere; bootstrap passwords are console-only, so
    # no host depends on interactive SSH auth.
    settings.KbdInteractiveAuthentication = false;
  };

  # networking.firewall.interfaces."${config.my.lan}".allowedTCPPorts = config.services.openssh.ports;
}
