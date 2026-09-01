{ ... }:
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
}
