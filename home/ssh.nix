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
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    matchBlocks = {
      "*" = {
        forwardAgent = isWorkstation;
      };
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

      "kradalby-llm" = {
        forwardAgent = false;
      };

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

  # Set SSH_AUTH_SOCK to 1Password agent only if not already set
  # This allows forwarded agents (ssh -A) to take priority
  home.sessionVariables = lib.mkIf isWorkstation {
    SSH_AUTH_SOCK = "$HOME/.ssh/ssh-agent-mux.sock";
  };
}
