{
  lib,
  pkgs,
  config,
  inputs,
  ...
}: let
  maxVMs = 5;

  secretPath = "/run/gh-runner/secrets";
in {
  age.secrets.github-headscale-token = {
    file = ../../secrets/github-headscale-token.age;
    path = "${secretPath}/github-headscale-token";
  };
  microvm = {
    vms = builtins.listToAttrs (
      map (index: let
        mac = "00:00:00:00:00:0${toString index}";
      in {
        name = "gh-runner-test${toString index}";
        value = {
          # The package set to use for the microvm. This also determines the microvm's architecture.
          # Defaults to the host system's package set if not given.
          inherit pkgs;

          # The configuration for the MicroVM.
          # Multiple definitions will be merged as expected.
          config = {
            microvm = {
              # hypervisor = "firecracker";
              shares = [
                {
                  tag = "ro-store";
                  source = "/nix/store";
                  mountPoint = "/nix/.ro-store";
                }
                {
                  tag = "secrets";
                  source = secretPath;
                  mountPoint = secretPath;
                }
              ];
              interfaces = [
                {
                  id = "vm${toString index}";
                  type = "tap";
                  inherit mac;
                }
              ];
            };

            system.stateVersion = config.system.nixos.version;
            networking = {
              hostName = "gh-runner-test${toString index}";
              useNetworkd = true;
            };

            systemd.network = {
              networks."10-eth" = {
                matchConfig.MACAddress = mac;
                # Static IP configuration
                address = [
                  "172.16.0.${toString index}/32"
                  "fec0::${lib.toHexString index}/128"
                ];
                routes = [
                  {
                    # A route to the host
                    Destination = "172.16.0.0/32";
                    GatewayOnLink = true;
                  }
                  {
                    # Default route
                    Destination = "0.0.0.0/0";
                    Gateway = "172.16.0.0";
                    GatewayOnLink = true;
                  }
                  {
                    # Default route
                    Destination = "::/0";
                    Gateway = "fec0::";
                    GatewayOnLink = true;
                  }
                ];
                networkConfig = {
                  DNS = [
                    "10.65.0.1"
                    "1.1.1.1"
                  ];
                };
              };
            };

            networking.firewall.enable = false;
            users.users.root.password = "toor";
            services.openssh = {
              enable = true;
              settings.PermitRootLogin = "yes";
            };

            users.users.github-runner = {
              isSystemUser = true;
              group = "docker";
            };

            virtualisation.docker.enable = true;

            # The GitHub Actions self-hosted runner service.
            services.github-runners.headscale = {
              enable = true;
              url = "https://github.com/kradalby/headscale";
              replace = true;
              extraLabels = ["nixos" "docker"];
              user = "github-runner";
              ephemeral = true;

              # Justifications for the packages:
              extraPackages = with pkgs; [
                docker
                nix
                nodejs
                gawk
                git
              ];

              name = "kradalby-${config.networking.hostName}-${toString index}";

              tokenFile = config.age.secrets.github-headscale-token.path;
            };
          };
        };
      }) (lib.genList (i: i + 1) maxVMs)
    );
  };
}
