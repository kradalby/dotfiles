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
