# Multi-service server profile: layered on top of common/base.nix by machines
# that run real services. Adds the heavier observability + mail daemons and a
# set of server-ops CLI tools. NOT imported by the minimal ts1p appliance.
{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ../common/systemd-exporter.nix
    ../common/smartctl-exporter.nix # inert until monitoring.smartctl.devices is set
  ];

  environment.systemPackages =
    with pkgs;
    [
      restic
      rclone
      smartmontools
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [
      usbutils
      (import ../pkgs/scripts/emergency-full-disk.nix { inherit pkgs; })
    ];

  # zpool scrub exits non-zero when a scrub is already running, so the timer's
  # post-boot catch-up fails the unit on pools that scrub for longer than the
  # interval. An ExecCondition skips the run instead of failing it.
  systemd.services = lib.mkIf config.services.zfs.autoScrub.enable {
    zfs-scrub.serviceConfig.ExecCondition = pkgs.writeShellScript "zfs-scrub-idle" ''
      ! ${config.boot.zfs.package}/bin/zpool status | grep -q 'scrub in progress'
    '';
  };
}
