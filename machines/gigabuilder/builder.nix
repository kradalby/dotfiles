{pkgs, ...}: {
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
    shell = "${pkgs.shadow}/bin/nologin"; # SSH-for-nix only, no interactive login
    openssh.authorizedKeys.keys = [
      # public half of the garnix VM's garnix-remote-builder-ssh secret:
      # "ssh-ed25519 AAAA... garnix-remote-builder"
    ];
  };

  # A remote builder's SSH user must be trusted to drive the daemon.
  nix.settings.trusted-users = ["nix-ssh"];
}
