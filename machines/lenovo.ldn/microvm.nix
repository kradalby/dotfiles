{
  lib,
  pkgs,
  config,
  inputs,
  ...
}: let
  maxVMs = 6;

  # vm = ["a" "b" "c" "d" "e" "f"];
  vm = ["a"];
  hypervisorMacAddrs = builtins.listToAttrs (
    map (hypervisor: let
      hash = builtins.hashString "sha256" hypervisor;
      c = off: builtins.substring off 2 hash;
      mac = "${builtins.substring 0 1 hash}2:${c 2}:${c 4}:${c 6}:${c 8}:${c 10}";
    in {
      name = hypervisor;
      value = mac;
    })
    vm
  );

  hypervisorIPv4Addrs = builtins.listToAttrs (
    lib.imap0 (i: hypervisor: {
      name = hypervisor;
      value = "172.16.0.${toString (2 + i)}";
    })
    vm
  );

  ethLink = name: (mac: {
    matchConfig = {
      Type = "ether";
      MACAddress = mac;
    };
    linkConfig = {
      Name = name;

      # Hardware tuning. Note that wan0/wan1/mgmt0 all happen to support a max
      # of 4096 since the NixOS option won't allow "max".
      RxBufferSize = 4096;
      TxBufferSize = 4096;
    };
  });

  lan = "enp0s31f6";

  secretPath = "/run/gh-runner/secrets";
  hostStateVersion = config.system.stateVersion;
in {
  age.secrets.github-headscale-token = {
    file = ../../secrets/github-headscale-token.age;
    path = "${secretPath}/github-headscale-token";
  };
  # microvm = {
  #   vms = builtins.listToAttrs (
  #     map (index: let
  #       mac = "00:00:00:00:00:0${toString index}";
  #     in {
  #       name = "gh-runner-test${toString index}";
  #       value = {
  #         # The package set to use for the microvm. This also determines the microvm's architecture.
  #         # Defaults to the host system's package set if not given.
  #         inherit pkgs;

  #         # The configuration for the MicroVM.
  #         # Multiple definitions will be merged as expected.
  #         config = {
  #           microvm = {
  #             # hypervisor = "firecracker";
  #             shares = [
  #               {
  #                 tag = "ro-store";
  #                 source = "/nix/store";
  #                 mountPoint = "/nix/.ro-store";
  #               }
  #               {
  #                 tag = "secrets";
  #                 source = secretPath;
  #                 mountPoint = secretPath;
  #               }
  #             ];
  #             interfaces = [
  #               {
  #                 id = "vm${toString index}";
  #                 type = "tap";
  #                 inherit mac;
  #               }
  #             ];
  #           };

  #           system.stateVersion = config.system.nixos.version;
  #           networking = {
  #             hostName = "gh-runner-test${toString index}";
  #             useNetworkd = true;
  #           };

  #           systemd.network = {
  #             enable = true;
  #             networks."10-eth" = {
  #               matchConfig.MACAddress = mac;
  #               # Static IP configuration
  #               address = [
  #                 "172.16.0.${toString index}/32"
  #                 "fec0::${lib.toHexString index}/128"
  #               ];
  #               routes = [
  #                 {
  #                   # A route to the host
  #                   Destination = "172.16.0.0/32";
  #                   GatewayOnLink = true;
  #                 }
  #                 {
  #                   # Default route
  #                   Destination = "0.0.0.0/0";
  #                   Gateway = "172.16.0.0";
  #                   GatewayOnLink = true;
  #                 }
  #                 {
  #                   # Default route
  #                   Destination = "::/0";
  #                   Gateway = "fec0::";
  #                   GatewayOnLink = true;
  #                 }
  #               ];
  #               networkConfig = {
  #                 DNS = [
  #                   "10.65.0.1"
  #                   "1.1.1.1"
  #                 ];
  #               };
  #             };
  #           };

  #           networking.firewall.enable = false;
  #           users.users.root.password = "toor";
  #           services.openssh = {
  #             enable = true;
  #             settings.PermitRootLogin = "yes";
  #           };

  #           users.users.github-runner = {
  #             isSystemUser = true;
  #             group = "docker";
  #           };

  #           virtualisation.docker.enable = true;

  #           # The GitHub Actions self-hosted runner service.
  #           services.github-runners.headscale = {
  #             enable = true;
  #             url = "https://github.com/kradalby/headscale";
  #             replace = true;
  #             extraLabels = ["nixos" "docker"];
  #             user = "github-runner";
  #             ephemeral = true;

  #             # Justifications for the packages:
  #             extraPackages = with pkgs; [
  #               docker
  #               nix
  #               nodejs
  #               gawk
  #               git
  #             ];

  #             name = "kradalby-${config.networking.hostName}-${toString index}";

  #             tokenFile = config.age.secrets.github-headscale-token.path;
  #           };
  #         };
  #       };
  #     }) (lib.genList (i: i + 1) maxVMs)
  #   );
  # };

  systemd.network = {
    enable = true;

    links = {
      "10-lan0" = ethLink "lan0" "6c:4b:90:2b:c7:d2";
    };

    networks = {
      "10-lan0" = {
        matchConfig.Name = "lan0";
        networkConfig.DHCP = "yes";
        # Never accept ISP DNS or search domains for any DHCP/RA family.
        dhcpV4Config = {
          UseDNS = true;
          UseDomains = false;
          SendRelease = false;
        };
      };
      "microvm-br0" = {
        addresses = lib.mkForce [
          {
            Address = "172.16.0.1/24";
          }
          {
            Address = "fd12:3456:789a::1/64";
          }
        ];
        # Let DHCP assign a statically known address to the VMs
        dhcpServerStaticLeases =
          lib.imap0 (i: hypervisor: {
            dhcpServerStaticLeaseConfig = {
              MACAddress = hypervisorMacAddrs.${hypervisor};
              Address = hypervisorIPv4Addrs.${hypervisor};
            };
          })
          vm;
      };
      "30-microvm-eth0" = {
        matchConfig.Name = "vm-*";
        networkConfig.Bridge = "microvm-br0";
      };
    };
  };
  # Allow DHCP server
  networking.firewall.allowedUDPPorts = [67];
  # Allow Internet access
  networking.nat = {
    enable = true;
    enableIPv6 = true;
    internalInterfaces = ["microvm-br0"];
  };

  networking.extraHosts =
    lib.concatMapStrings (hypervisor: ''
      ${hypervisorIPv4Addrs.${hypervisor}} ${hypervisor}
    '')
    vm;

  networking = {
    hostId = "007f0200";
    hostName = "lenovo";
    domain = "ldn.fap.no";
  };

  microvm.vms =
    builtins.mapAttrs (hypervisor: mac: {
      config = {
        system.stateVersion = hostStateVersion;
        networking.hostName = "${hypervisor}-microvm";

        microvm = {
          hypervisor = "qemu";
          interfaces = [
            {
              type = "tap";
              id = "vm-${builtins.substring 0 12 hypervisor}";
              inherit mac;
            }
          ];
        };
        systemd.network.enable = true;

        users.users.root.password = "toor";
        services.openssh = {
          enable = true;
          settings.PermitRootLogin = "yes";
        };
      };
    })
    hypervisorMacAddrs;
}
