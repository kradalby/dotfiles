{ lib, config }:
with lib;
with builtins;
let
  baseDomain = ".fap.no";

  currentSite = builtins.replaceStrings [ baseDomain ] [ "" ] config.networking.domain;

  consulPeers =
    mapAttrs (key: value: value.consul) (filterAttrs (key: hasAttr "consul") (removeAttrs sites [ currentSite ]));

  consul =
    mapAttrs (key: value: value.consul) (filterAttrs (key: hasAttr "consul") sites);

  nameservers = lib.unique (lib.flatten (attrValues (mapAttrs (name: site: site.nameservers) sites)));

  sites =
    {
      ntnu =
        let
          ipv4Gateway = "10.61.0.1";
        in
        {
          name = "ntnu";
          nameservers = [ ipv4Gateway ];
          consul = ipv4Gateway;
          openvpn = "10.61.200.0";
          inherit ipv4Gateway;
        };
      ldn =
        let
          ipv4Gateway = "10.65.0.1";
        in
        {
          name = "ldn";
          nameservers = [ ipv4Gateway ];
          consul = ipv4Gateway;
          openvpn = "10.65.200.0";
          inherit ipv4Gateway;
        };
      oracldn =
        let
          ipv4Gateway = "10.66.0.1";
        in
        {
          name = "oracldn";
          nameservers = [ ipv4Gateway ];
          consul = ipv4Gateway;
          openvpn = "10.66.200.0";
          inherit ipv4Gateway;
        };
      oracfurt =
        let
          ipv4Gateway = "10.67.0.1";
        in
        {
          name = "oracfurt";
          nameservers = [ ipv4Gateway ];
          consul = ipv4Gateway;
          openvpn = "10.67.200.0";
          inherit ipv4Gateway;
        };
      terra =
        let
          ipv4Gateway = "10.60.0.1";
        in
        {
          name = "terra";
          nameservers = [ ipv4Gateway ];
          openvpn = "10.60.200.0";
          k3s = {
            master = "10.60.0.111";
            clusterCidr = "10.60.4.0/24";
            serviceCidr = "10.60.5.0/24";
          };
          inherit ipv4Gateway;
        };
      tjoda =
        let
          ipv4Gateway = "10.62.0.1";
        in
        {
          name = "tjoda";
          nameservers = [ ipv4Gateway ];
          openvpn = "10.62.200.0";
          inherit ipv4Gateway;
        };

    };
in
{
  inherit baseDomain currentSite consulPeers consul nameservers sites;
}
