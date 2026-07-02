{
  pkgs,
  config,
  ...
}: {
  # gigabuilder as the garnix VM's remote nix builder: it offloads realisation
  # here over SSH (incusbr0 is trusted, so no extra firewall rule), builds in the
  # sandbox, and populates the host store tsnixcache serves.
  users.groups.nix-ssh = {};
  users.users.nix-ssh = {
    isSystemUser = true;
    group = "nix-ssh";
    shell = "${pkgs.bashInteractive}/bin/bash"; # forced command runs via $SHELL -c; nologin breaks it
    # Pin the key to the nix-daemon protocol only. nix-ssh is still a trusted nix
    # user (a remote builder must be), so this caps SSH surface, not the reach.
    openssh.authorizedKeys.keys = [
      "command=\"${config.nix.package}/bin/nix-daemon --stdio\",restrict ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB/gPdHyIXk4sq1+ZskMFEt2Kn1IDQU0k9sTolwl4UA2 garnix-remote-builder"
    ];
  };
  nix.settings.trusted-users = ["nix-ssh"];

  # Confine builds to cores 4-31, leaving 0-3 for the co-located garnix VM
  # (pinned there in ~/git/infrastructure). Without this, offloaded builds starve
  # the VM's vcpus and incus resets it (~80-min crash-loop under load).
  systemd.services.nix-daemon.serviceConfig.CPUAffinity = "4-31";
}
