# The kernel kills only once memory and swap are gone, and long before that a
# box can thrash so hard that nothing answers. earlyoom kills while there is
# still room to work, one process at a time by oom_score, so a host's
# OOMScoreAdjust ordering still decides who goes first. Per process, not
# systemd-oomd's whole cgroup, which takes every sibling down with it.
{ config, lib, ... }:
{
  services.earlyoom = {
    # MemAvailable leaves out the ZFS ARC, so an ARC the kernel would shrink on
    # demand reads to earlyoom as memory already gone.
    enable = lib.mkDefault (!config.boot.zfs.enabled);
    # The way back in to a struggling host. Each is small, so killing one frees
    # little and costs the access needed to fix it.
    extraArgs = [
      "--ignore"
      "^(sshd|sshd-session|tailscaled|rex)$"
    ];
  };
}
