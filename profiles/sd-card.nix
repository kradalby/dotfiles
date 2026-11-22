{ lib, ... }:
{
  imports = [
    ../common/tmp.nix
    ../common/journal-volatile.nix
  ];

  fileSystems."/var/log" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [
      "size=16M"
      "mode=0755"
      "nosuid"
      "nodev"
    ];
  };
  # Rotate RAM-backed login logs without updating a state file on the card.
  services.logrotate.extraArgs = [
    "--state"
    "/var/log/logrotate.status"
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
