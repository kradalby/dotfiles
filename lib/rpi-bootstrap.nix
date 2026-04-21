{
  nixpkgs,
  nixos-generators,
  inputs,
  overlays,
}: {
  name ? "bootstrap",
  hardwareModule,
  extraOverlays ? [],
  extraModules ? [],
  kadPsk ? "",
  tsAuthKey ? "",
  tags ? ["tag:server"],
}: let
  pkgs = import nixpkgs {
    system = "aarch64-linux";
    inherit overlays;
  };
in
  nixos-generators.nixosGenerate {
    system = "aarch64-linux";
    format = "sd-aarch64";
    specialArgs = {inherit inputs;};
    modules =
      [
        inputs.ragenix.nixosModules.age
        inputs.tailscale.nixosModules.default
        ../common
        ../common/tailscale.nix
        hardwareModule
        {
          nixpkgs.overlays = extraOverlays;

          networking = {
            hostName = name;
            domain = "bootstrap.fap.no";
            firewall.enable = pkgs.lib.mkForce false;
            useDHCP = pkgs.lib.mkForce true;

            wireless = {
              enable = true;
              networks."_kad".psk = kadPsk;
            };
          };

          # networkd default DHCP match only covers eth*/en*.
          systemd.network.networks."40-wlan" = {
            matchConfig.Name = "wl*";
            networkConfig.DHCP = "yes";
            dhcpV4Config.RouteMetric = 2048;
          };

          services.tailscale = {
            authKeyFile =
              pkgs.lib.mkForce (pkgs.writeText "authkey" tsAuthKey);
            inherit tags;
          };
        }
      ]
      ++ extraModules;
  }
