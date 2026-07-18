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
}
