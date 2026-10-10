{
  pkgs,
  lib,
  ...
}:
let
  isWorkstation = pkgs.stdenv.hostPlatform.isDarwin && pkgs.stdenv.hostPlatform.isAarch64;
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
in
{
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
      "tailscale-proxy".header =
        "Match host !bunny.corp.tailscale.com,*.tailscale.com,control,shard*,derp*,trunkd*";
    };
  };

  # Local Mac sessions use 1Password; SSH sessions keep their forwarded agent.
  home.sessionVariablesExtra = lib.mkIf isWorkstation ''
    if [ -z "''${SSH_CONNECTION-}" ] || [ -z "''${SSH_AUTH_SOCK-}" ]; then
      export SSH_AUTH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    fi
  '';
}
