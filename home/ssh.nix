{pkgs, ...}: let
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
    extraConfig =
      if isWorkstation
      then ''
        IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
      ''
      else "";

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
    };
  };
}
