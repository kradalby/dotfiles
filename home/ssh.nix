{
  pkgs,
  lib,
  ...
}: let
  isWorkstation = pkgs.stdenv.isDarwin && pkgs.stdenv.isAarch64;
  kradalbyLogin = hostname: {
    HostName = hostname;
    User = "kradalby";
    Port = 22;
  };
  fapRoot = {
    HostName = "%h.fap.no";
    User = "root";
    Port = 22;
  };
in {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings = {
      "*".ForwardAgent = isWorkstation;
      "devl" = kradalbyLogin "dev.ldn.fap.no";
      "devf" = kradalbyLogin "dev.oracfurt.fap.no";
      "*.s" = {
        HostName = "%handefjordfiber.no";
        User = "root";
        Port = 22;
        ProxyJump = "core.terra.fap.no";
      };
      "*.terra" = fapRoot;
      "*.tjoda" = fapRoot;
      "*.ldn" = fapRoot;
      "*.oracldn" = fapRoot;
      "*.oracfurt" = fapRoot;

      "kradalby-llm".ForwardAgent = false;

      # Tailscale configuration
      "bunny*".User = "ubuntu";
      "control*".User = "ubuntu";
      "kradalby-workstation*".User = "ubuntu";
      "tailscale-proxy".header = "Match host !bunny.corp.tailscale.com,*.tailscale.com,control,shard*,derp*,trunkd*";
    };
  };

  # Set SSH_AUTH_SOCK to 1Password agent only if not already set
  # This allows forwarded agents (ssh -A) to take priority
  home.sessionVariables = lib.mkIf isWorkstation {
    SSH_AUTH_SOCK = "$HOME/.ssh/ssh-agent-mux.sock";
  };
}
