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

  # proxy.golang.org 403s the signed storage.googleapis.com redirect from this
  # host, so every buildGoModule vendor fetch fails here while succeeding
  # elsewhere. Fetch from the source repos instead. GOPROXY is an impure env var
  # for those fixed-output derivations (pkgs/build-support/go/module.nix), so
  # this changes no vendorHash — only where the bytes come from. go.sum and the
  # checksum database still verify them.
  systemd.services.nix-daemon.environment.GOPROXY = "direct";
}
