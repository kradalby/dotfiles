# SMART-monitored disks per host, keyed by the dashed tailnet name (matches the
# `host` label). Single source of truth for both the per-host smartctl exporter
# (machines/<host>/default.nix: `monitoring.smartctl.devices`) and the
# SmartctlDiskMissing alert's expected count (machines/core.oracldn/
# monitoring.nix). Adding or removing a disk here updates both at once, so the
# alert count can never silently drift from the exporter's device list.
{
  core-tjoda = [
    "/dev/disk/by-id/ata-CT250MX500SSD1_1914E1F7A84D"
    "/dev/disk/by-id/ata-HGST_HUS728T8TALE6L4_VG0D0SZG"
    "/dev/disk/by-id/ata-KINGSTON_SA400S37480G_50026B7785A27E08"
    "/dev/disk/by-id/ata-Samsung_SSD_850_EVO_500GB_S2RBNXAH342406T"
    "/dev/disk/by-id/ata-WDC_WDS200T2B0A-00SM50_23014N802795"
  ];
  gigabuilder = [
    "/dev/nvme0n1"
    "/dev/nvme1n1"
  ];
  storage-bassan = [
    "/dev/sda"
    "/dev/nvme0n1"
  ];
}
