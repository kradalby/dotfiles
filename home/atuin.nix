# atuin shell-history sync client. Opt-in per host (like home/herdr.nix) so it
# only lands on the machines granted svc:atuin — enabling it elsewhere would
# just fail to sync. The two-account split (personal vs work) is runtime state
# (`atuin login`/`register`), not config, so it lives outside nix.
{
  config,
  lib,
  ...
}: {
  options.my.atuin.enable = lib.mkEnableOption "atuin shell-history sync client";

  config = lib.mkIf config.my.atuin.enable {
    programs.atuin = {
      enable = true;
      enableFishIntegration = true;
      # Keep fish's own up-arrow history; atuin search stays on ctrl-r.
      flags = ["--disable-up-arrow"];
      settings = {
        # VIP on the home tailnet. http, not https: the tcp:443 VIP endpoint
        # does not TLS-terminate (tailscale/tailscale#19724, #18381).
        sync_address = "http://atuin.dalby.ts.net";
        auto_sync = true;
        sync_frequency = "5m";
      };
    };
  };
}
