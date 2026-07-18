# dev.oracfurt as the garnix VM's aarch64 remote builder. garnix's fleet is
# otherwise x86_64-only (gigabuilder), so its Oracle/rpi nixosConfig checks had
# no aarch64 builder and never built. This host is native aarch64 and near-idle.
#
# Reached over the tailnet, but Tailscale SSH owns tailnet :22 and authenticates
# by tailnet identity — it never consults the nix-ssh authorized_keys, so the
# forced-command build key can't work there. Run a second sshd port that
# tailscale-ssh does not intercept (only :22) and point garnix at it.
{ lib, ... }:
{
  imports = [ ../../common/garnix-build-target.nix ];

  services.openssh.ports = [
    22
    2222
  ];
  # Only the tailnet reaches the build port; never the WAN.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 2222 ];

  # box.nix forces max-jobs=0 on buildOnTarget=false hosts (they offload their
  # own builds to the fleet). As garnix's aarch64 build target this host must
  # build locally, or remote builds fail "local builds are disabled".
  nix.settings.max-jobs = lib.mkForce "auto";
}
