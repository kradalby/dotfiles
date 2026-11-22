{ lib, ... }:
{
  imports = [
    ../common/tmp.nix
    ../common/journal-volatile.nix
  ];

  services.journald.extraConfig = "RuntimeMaxUse=32M";
  services.tailscale.disableUpstreamLogging = lib.mkDefault true;
  systemd.coredump.settings.Coredump = {
    Storage = "none";
    ProcessSizeMax = 0;
  };
  zramSwap.enable = lib.mkDefault true;
  # Store optimisation rewrites directory entries even on a remotely built host.
  nix.optimise.automatic = lib.mkForce false;
}
