{pkgs, config, ...}: {
  # gigabuilder as a remote nix builder for the garnix VM. The VM's
  # services.garnixServer.remoteBuilders offloads all realisation here over SSH;
  # builds run in the standard nix sandbox and populate the host /nix/store that
  # tsnixcache serves.
  #
  # GATED: imported only once the garnix VM exists and its remote-builder key is
  # known. incusbr0 is already a trustedInterface, so the VM (10.68.10.x) reaches
  # 10.68.0.1:22 with no extra firewall rule.
  users.groups.nix-ssh = {};
  users.users.nix-ssh = {
    isSystemUser = true;
    group = "nix-ssh";
    shell = "${pkgs.bashInteractive}/bin/bash"; # forced command below runs via $SHELL -c, so nologin won't do
    # Pin the key to the nix-daemon stdio protocol only — no interactive shell,
    # no port/agent/X11 forwarding. nix-ssh is still a trusted nix user (a remote
    # builder must be, to import the coordinator's unsigned closures), so this
    # caps the SSH surface but not the inherent trusted-user → root reach.
    openssh.authorizedKeys.keys = [
      "command=\"${config.nix.package}/bin/nix-daemon --stdio\",restrict ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB/gPdHyIXk4sq1+ZskMFEt2Kn1IDQU0k9sTolwl4UA2 garnix-remote-builder"
    ];
  };

  # A remote builder's SSH user must be trusted to drive the daemon.
  nix.settings.trusted-users = ["nix-ssh"];

  # Confine the nix-daemon and its build children to host cores 4-31, leaving
  # 0-3 for the co-located garnix VM (pinned there in
  # ~/git/infrastructure/incus). Without this, the ~16 offloaded builds saturate
  # all 32 cores and starve the VM's vcpus, which incus then resets (~80-min
  # crash-loop under headscale load). 28 cores is ample for maxJobs.
  systemd.services.nix-daemon.serviceConfig.CPUAffinity = "4-31";
}
