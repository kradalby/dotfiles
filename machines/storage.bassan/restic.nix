{ ... }:
{
  # Offsite via the Jotta proxy on core.tjoda (no Jotta credentials here).
  # Deliberately does NOT back up the /storage sync datasets: that data is
  # already uploaded to Jotta by storage.ldn directly, and this host is an
  # (encrypted) mirror of it — re-uploading would just be a second copy of
  # identical data on the same provider. Back up only host-local, non-replicated,
  # non-rebuildable state.
  services.restic.jobs.jotta = {
    # Inert until the age secret exists (created at deploy); keeps the host
    # buildable before then and auto-enables once the token is in the repo.
    enable = builtins.pathExists ../../secrets/restic-storage-bassan-token.age;
    site = "jotta";
    # Opaque per-host repo folder on Jotta (house convention: scrambled name,
    # nothing host-identifying on the provider side).
    targetHost = "4d4d0d89ab4bfedfbbcde27fb0b87cdd";
    secret = "restic-storage-bassan-token";
    paths = [ "/etc/nixos" ];
    # Jotta egress is paid/slow: verify metadata only, monthly.
    check = {
      args = [ ];
      interval = "monthly";
    };
  };
}
