# Be a remote nix build target for the self-hosted garnix VM (machines/garnix):
# garnix offloads realisation here over SSH as nix-ssh, builds in the sandbox,
# and the tsnixcache watch client pushes the outputs to the cache. Imported by
# gigabuilder (x86_64, reached over incusbr0) and dev.oracfurt (aarch64, over
# the tailnet). Single source for the trusted builder key so it can't drift.
{
  pkgs,
  config,
  ...
}:
{
  users.groups.nix-ssh = { };
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
  nix.settings.trusted-users = [ "nix-ssh" ];
}
