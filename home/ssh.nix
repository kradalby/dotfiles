{
  pkgs,
  lib,
  ...
}: let
  isWorkstation = pkgs.stdenv.isDarwin && pkgs.stdenv.isAarch64;
  kradalbyLogin = hostname: {
    hostname = hostname;
    user = "kradalby";
    port = 22;
  };
  fapRoot = {
    hostname = "%h.fap.no";
    user = "root";
    port = 22;
  };
in {
  # Set SSH_AUTH_SOCK to 1Password agent only if not already set
  # This allows forwarded agents (ssh -A) to take priority
  home.sessionVariablesExtra = lib.mkIf isWorkstation ''
    export SSH_AUTH_SOCK="''${SSH_AUTH_SOCK:-$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock}"
  '';

  programs.ssh = {
    enable = true;
    forwardAgent = isWorkstation;

    matchBlocks = {
      "sprocket" = kradalbyLogin "sprocket.nvg.ntnu.no";
      "devl" = kradalbyLogin "dev.ldn.fap.no";
      "devf" = kradalbyLogin "dev.oracfurt.fap.no";
      "*.s" = {
        hostname = "%handefjordfiber.no";
        user = "root";
        port = 22;
        proxyJump = "core.terra.fap.no";
      };
      "*.terra" = fapRoot;
      "*.tjoda" = fapRoot;
      "*.ldn" = fapRoot;
      "*.oracldn" = fapRoot;
      "*.oracfurt" = fapRoot;

      # Tailscale configuration
      "bunny*" = {
        user = "ubuntu";
      };
      "control*" = {
        user = "ubuntu";
      };
      "kradalby-workstation*" = {
        user = "ubuntu";
      };
      "tailscale-proxy" = {
        match = "host !bunny.corp.tailscale.com,*.tailscale.com,control,shard*,derp*,trunkd*";
      };
    };
  };
}
