# Multi-service server profile: layered on top of common/base.nix by machines
# that run real services. Adds the heavier observability + mail daemons and a
# set of server-ops CLI tools. NOT imported by the minimal ts1p appliance.
{
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ../common/systemd-exporter.nix
    ../common/smartctl-exporter.nix # inert until monitoring.smartctl.devices is set
    # postfix moved to common/base.nix so every machine — not just servers —
    # relays mail through gigabuilder (smtp.fap.no -> spamvask.terrahost.no).
  ];

  environment.systemPackages =
    with pkgs;
    [
      restic
      rclone
      smartmontools
    ]
    ++ lib.optionals stdenv.isLinux [
      usbutils
      (import ../pkgs/scripts/emergency-full-disk.nix { inherit pkgs; })
    ];
}
