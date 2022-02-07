{ config, pkgs, lib }:
let
  server = site:
    {
      age.secrets."k3s-${site.name}".file = ../../secrets + "/k3s-${site.name}.age";

      environment.systemPackages = [
        (pkgs.writeShellScriptBin "k3s-reset-node" (builtins.readFile ./k3s-reset-node))
        pkgs.nfs-utils
      ];

      networking.firewall.allowedTCPPorts = [
        6443 # API Server
        10250 # Kubelet API
        7946 # MetalLB
        179 # BGP / Bird
        80 # HTTP
        443 # HTTPS
      ];
      networking.firewall.allowedUDPPorts = [
        8472 # Flannel VXLAN
        7946 # MetalLB
      ];
      # networking.firewall.logRefusedPackets = true;

      # Workaround for mount rpc issue
      # https://github.com/NixOS/nixpkgs/issues/76671
      services.nfs.server.enable = true;
      services.rpcbind.enable = true;

      services.k3s = {
        enable = true;
        role = "server";

        extraFlags = builtins.concatStringsSep " " [
          "--disable traefik"
          "--disable servicelb"
          "--disable local-storage"
          # "--flannel-backend=none"
          # "--disable-network-policy"
          # "--cluster-cidr ${site.k3s.clusterCidr}"
          # "--service-cidr ${site.k3s.serviceCidr}"
        ];

        tokenFile = config.age.secrets."k3s-${site.name}".path;
      };
    };

  agent = site:
    {
      age.secrets."k3s-${site.name}".file = ../../secrets + "/k3s-${site.name}.age";

      environment.systemPackages = [
        (pkgs.writeShellScriptBin "k3s-reset-node" (builtins.readFile ./k3s-reset-node))
        pkgs.nfs-utils
      ];

      networking.firewall.allowedTCPPorts = [
        10250 # Kubelet API
        7946 # MetalLB
        179 # BGP / Bird
        80 # HTTP
        443 # HTTPS
      ];
      networking.firewall.allowedUDPPorts = [
        8472 # Flannel VXLAN
        7946 # MetalLB
      ];

      # Workaround for mount rpc issue
      # https://github.com/NixOS/nixpkgs/issues/76671
      services.nfs.server.enable = true;
      services.rpcbind.enable = true;

      services.k3s = {
        enable = true;
        role = "agent";
        serverAddr = "https://${site.k3s.master}:6443";

        tokenFile = config.age.secrets."k3s-${site.name}".path;
      };
    };
in
{ inherit server agent; }
