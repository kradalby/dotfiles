{ config, pkgs, lib }:
let
  server = site:
    {
      age.secrets."k3s-${site.name}".file = ../../secrets + "/k3s-${site.name}.age";

      environment.systemPackages = [
        (pkgs.writeShellScriptBin "k3s-reset-node" (builtins.readFile ./k3s-reset-node))
      ];

      networking.firewall.allowedTCPPorts = [ 6443 ];

      services.k3s = {
        enable = true;
        role = "server";

        extraFlags = builtins.concatStringsSep " " [
          "--disable traefik"
          "--disable servicelb"
          "--disable local-storage"
          "--flannel-backend=none"
          "--disable-network-policy"
          "--cluster-cidr ${site.k3s.clusterCidr}"
          "--service-cidr ${site.k3s.serviceCidr}"
        ];

        tokenFile = config.age.secrets."k3s-${site.name}".path;
      };
    };

  agent = site:
    {
      age.secrets."k3s-${site.name}".file = ../../secrets + "/k3s-${site.name}.age";

      environment.systemPackages = [
        (pkgs.writeShellScriptBin "k3s-reset-node" (builtins.readFile ./k3s-reset-node))
      ];

      services.k3s = {
        enable = true;
        role = "agent";
        serverAddr = "https://${site.k3s.master}:6443";

        tokenFile = config.age.secrets."k3s-${site.name}".path;
      };
    };
in
{ inherit server agent; }
