{ pkgs, ... }:
{
  # gigabuilder as the garnix VM's remote x86_64 nix builder: it offloads
  # realisation here over SSH (incusbr0 is trusted, so no extra firewall rule),
  # builds in the sandbox, and populates the host store tsnixcache serves. The
  # nix-ssh build user + trusted key are shared with dev.oracfurt (aarch64).
  imports = [ ../../common/garnix-build-target.nix ];

  # Confine builds to cores 4-31, leaving 0-3 for the co-located garnix VM
  # (pinned there in ~/git/infrastructure). Without this, offloaded builds starve
  # the VM's vcpus and incus resets it (~80-min crash-loop under load).
  systemd.services.nix-daemon.serviceConfig.CPUAffinity = "4-31";

  # The same reservation for memory, and the same for kill preference. The VM
  # lives in incus.service's cgroup and offloaded builds are the largest memory
  # consumer on the box, so a global OOM picks the qemu process running the VM:
  # the builder kills the coordinator that dispatched the build, taking CI down
  # and cancelling every in-flight job across every repo. cgroup v2 spares tasks
  # in a cgroup under its memory.min, and the negative OOMScoreAdjust (inherited
  # by the qemu children) moves the VM out of the victim shortlist.
  systemd.services.incus.serviceConfig = {
    MemoryMin = "20G";
    ManagedOOMPreference = "avoid";
    OOMScoreAdjust = -500;
  };

  # Bound what the builds themselves can take. Defaults are cores = 0 and
  # max-jobs = auto, which on this box means each derivation gets all 32 CPUs
  # and up to 32 run at once — memory demand no dispatch-side limit can restrain,
  # which is why capping garnix's build pool did not stop the OOM. 6 x 4 fits the
  # 28 cores CPUAffinity actually permits and matches the pool size garnix
  # dispatches with (machines/garnix/default.nix); change them together.
  nix.settings = {
    cores = 4;
    max-jobs = 6;
  };

  # Margin, not mechanism. The shield below is what moves the guest down the
  # list; this only widens the gap, so do not delete the shield believing this
  # covers it. Measured on the box: a 78MB Go builder at adj=0 scored 667 while
  # the 16GiB guest at adj=-500 scored 506 — oom_score is not the size ranking
  # badness(RSS) suggests, so rank by reading the actual scores, never by
  # reasoning from RSS. nix never rewrites oom_score_adj, so builds inherit this
  # from the daemon at fork.
  systemd.services.nix-daemon.serviceConfig.OOMScoreAdjust = 500;

  # And lower the side we are not. OOMScoreAdjust on incus.service reaches
  # incusd only: incus resets oom_score_adj on the qemu processes it spawns, so
  # the guest lands back at 0 and near the top of the victim list. Nothing
  # declarative reaches those processes, hence this.
  #
  # It exits non-zero when it finds no guest to protect. A protection that
  # quietly does nothing is worse than one that is visibly absent — that is the
  # exact trap that let the VM sit unprotected after a reboot.
  systemd.services.incus-guest-oom-shield = {
    description = "Keep incus guests off the OOM killer's shortlist";
    after = [ "incus.service" ];
    wants = [ "incus.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      shielded=0
      for pid in $(${pkgs.procps}/bin/pgrep -f qemu-system-x86_64 || true); do
        echo -500 > "/proc/$pid/oom_score_adj" && shielded=$((shielded + 1))
      done
      if [ "$shielded" -eq 0 ]; then
        echo "no incus guest qemu process found; guests are unprotected" >&2
        exit 1
      fi
      echo "shielded $shielded incus guest process(es)"
    '';
  };

  # The shield only holds until a guest restarts, which incus does on its own.
  # Re-assert it rather than trusting a single pass at boot.
  systemd.timers.incus-guest-oom-shield = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "5min";
    };
  };
}
