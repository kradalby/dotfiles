{ lib, ... }: {
  networking.firewall = {
    enable = true;
    allowPing = true;
    checkReversePath = lib.mkDefault "strict";
    trustedInterfaces = [ "tailscale0" "wg0" ];
    logRefusedConnections = lib.mkDefault false;
  };
}
