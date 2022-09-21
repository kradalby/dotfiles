{
  pkgs,
  lib,
  ...
}:
with lib; let
  base = {
    hostName,
    interface,
    ipv4,
    site,
  }:
    {
      inherit hostName;
      inherit (site) nameservers;
      domain = "${site.name}.fap.no";
      defaultGateway = site.ipv4Gateway;
      dhcpcd.enable = false;
      usePredictableInterfaceNames = lib.mkForce true;
      interfaces = {
        "${interface}" = {
          ipv4.addresses = [
            {
              address = ipv4;
              prefixLength = 24;
            }
          ];
          ipv4.routes = [
            {
              address = site.ipv4Gateway;
              prefixLength = 32;
            }
          ];
        };
      };
    }
    // optionalAttrs (builtins.hasAttr "ipv6Gateway" site) {
      defaultGateway6 = site.ipv6Gateway;
    };
in {
  inherit base;
}
