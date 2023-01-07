{
  description = "kradalby's system config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11";
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-22.11-darwin";

    nixpkgs-headscale-test.url = "github:kradalby/nixpkgs/headscale-rfc0042";

    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    nixpkgs-staging.url = "github:NixOS/nixpkgs/staging";
    nixpkgs-staging-next.url = "github:NixOS/nixpkgs/staging-next";

    nixpkgs-hardware.url = "github:NixOS/nixos-hardware";

    darwin.url = "github:lnl7/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs-darwin";

    darwin-unstable.url = "github:lnl7/nix-darwin/master";
    darwin-unstable.inputs.nixpkgs.follows = "nixpkgs-unstable";

    darwin-master.url = "github:lnl7/nix-darwin/master";
    darwin-master.inputs.nixpkgs.follows = "nixpkgs-master";

    darwin-staging.url = "github:lnl7/nix-darwin/master";
    darwin-staging.inputs.nixpkgs.follows = "nixpkgs-staging";

    home-manager.url = "github:nix-community/home-manager/release-22.11";
    home-manager-unstable.url = "github:nix-community/home-manager/master";
    home-manager-unstable.inputs.nixpkgs.follows = "nixpkgs-unstable";

    ragenix.url = "github:yaxitech/ragenix";

    nur.url = "github:nix-community/NUR";

    fenix = {
      url = "github:nix-community/fenix";
      # inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-utils.url = "github:numtide/flake-utils";

    deadnix.url = "github:astro/deadnix";
    alejandra.url = "github:kamadorueda/alejandra";
    headscale.url = "github:juanfont/headscale";
    colmena.url = "github:zhaofengli/colmena";

    hugin.url = "github:kradalby/hugin/flake";
    munin.url = "github:kradalby/munin";
    golink.url = "github:tailscale/golink/kristoffer/nixmodule";
    nurl.url = "github:nix-community/nurl";
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-unstable,
    nixpkgs-master,
    nixpkgs-staging,
    nixpkgs-staging-next,
    darwin,
    darwin-unstable,
    darwin-master,
    darwin-staging,
    home-manager,
    home-manager-unstable,
    ragenix,
    nur,
    fenix,
    nixos-generators,
    flake-utils,
    deadnix,
    alejandra,
    headscale,
    colmena,
    hugin,
    munin,
    golink,
    nurl,
    ...
  } @ flakes: let
    overlay-pkgs = final: prev: {
      stable = import nixpkgs {inherit (final) system;};
      unstable = import nixpkgs-unstable {inherit (final) system;};
      master = import nixpkgs-master {inherit (final) system;};
      staging = import nixpkgs-staging {inherit (final) system;};
      staging-next = import nixpkgs-staging-next {inherit (final) system;};
    };

    overlays = [
      nur.overlay
      overlay-pkgs
      fenix.overlays.default
      ragenix.overlays.default
      deadnix.overlays.default
      alejandra.overlay
      headscale.overlay
      colmena.overlay
      hugin.overlay
      munin.overlay
      golink.overlay
      (import ./pkgs/overlays {})
      (final: prev: {
        nurl = nurl.packages."${prev.system}".default;
      })
    ];

    commonModules = [
      ragenix.nixosModules.age

      {
        nixpkgs.overlays = overlays;
      }
    ];

    nixosBox = arch: base: homeBase: name:
      base.lib.nixosSystem {
        system = arch;
        modules =
          commonModules
          ++ [
            hugin.nixosModules.default
            golink.nixosModules.default
            (import ./modules/linux.nix)
            {
              system.configurationRevision =
                self.rev or "DIRTY";
            }

            (./. + "/machines/${name}")
          ]
          ++ (
            if builtins.isNull homeBase
            then []
            else [
              homeBase.nixosModules.home-manager
              ./common/home.nix
            ]
          );
        specialArgs = {
          inherit flakes;
        };
      };

    macBox = machine: base: homeBase:
      base.lib.darwinSystem {
        system = machine.arch;
        modules =
          commonModules
          ++ [
            (./. + "/machines/${machine.hostname}")
            homeBase.darwinModules.home-manager
          ];
        specialArgs = {
          inherit flakes;
          inherit machine;
        };
      };

    homeOnly = machine: homeBase:
      homeBase.lib.homeManagerConfiguration {
        inherit (machine) username;
        system = machine.arch;
        homeDirectory = machine.homeDir;
        configuration.imports = [./home];
        extraModules =
          commonModules
          ++ [
            (./. + "/machines/${machine.hostname}")
          ];
      };

    mkColmenaFromNixOSConfigurations = nixosConfigurations:
      {
        meta = {
          machinesFile = /etc/nix/machines;
          nixpkgs = import nixpkgs {
            system = "x86_64-linux";
            inherit overlays;
          };

          specialArgs = {
            inherit flakes;
          };
        };
      }
      // builtins.mapAttrs
      (name: value: {
        deployment.buildOnTarget =
          # TODO(kradalby): aarch64 linux machines get grumpy about some
          # delegation stuff
          if value.config.nixpkgs.system == "aarch64-linux"
          then true
          else false;
        nixpkgs.system = value.config.nixpkgs.system;
        imports = value._module.args.modules;
      })
      nixosConfigurations;
  in
    {
      nixosConfigurations = {
        "core.terra" = nixosBox "x86_64-linux" nixpkgs home-manager "core.terra";

        "core.oracldn" = nixosBox "aarch64-linux" nixpkgs home-manager "core.oracldn";
        "headscale.oracldn" = nixosBox "x86_64-linux" nixpkgs null "headscale.oracldn";

        "dev.oracfurt" = nixosBox "aarch64-linux" nixpkgs home-manager "dev.oracfurt";

        # "core.ntnu" = nixosBox "x86_64-linux" nixpkgs null "core.ntnu";

        # nixos-generate --system aarch64-linux -f sd-aarch64 -I nixpkgs=channel:nixos
        "home.ldn" = nixosBox "aarch64-linux" nixpkgs null "home.ldn";
        "core.ldn" = nixosBox "aarch64-linux" nixpkgs null "core.ldn";
        # "storage.bassan" = nixosBox "aarch64-linux" nixpkgs null "storage.bassan";
        "core.tjoda" = nixosBox "x86_64-linux" nixpkgs null "core.tjoda";
      };

      # darwin-rebuild switch --flake .#kramacbook
      darwinConfigurations = {
        kramacbook = let
          machine = {
            arch = "x86_64-darwin";
            username = "kradalby";
            hostname = "kramacbook";
            homeDir = /Users/kradalby;
          };
        in
          macBox machine darwin home-manager;

        kratail = let
          machine = {
            arch = "aarch64-darwin";
            username = "kradalby";
            hostname = "kratail";
            homeDir = /Users/kradalby;
          };
        in
          macBox machine darwin home-manager;

        kraairm2 = let
          machine = {
            arch = "aarch64-darwin";
            username = "kradalby";
            hostname = "kraairm2";
            homeDir = /Users/kradalby;
          };
        in
          macBox machine darwin home-manager;
      };

      homeConfigurations = {
        # nix run github:nix-community/home-manager/master --no-write-lock-file -- switch --flake .#multipass
        "kradalby" = let
          machine = {
            arch = "x86_64-linux";
            username = "kradalby";
            hostname = "kradalby.home";
            homeDir = "/home/kradalby";
          };
        in
          homeOnly machine home-manager;
      };

      colmena = mkColmenaFromNixOSConfigurations self.nixosConfigurations;
    }
    // flake-utils.lib.eachDefaultSystem
    (system: let
      pkgs = import nixpkgs {
        inherit overlays;
        inherit system;
      };
    in rec {
      devShell = pkgs.mkShell {
        buildInputs = [
          pkgs.alejandra
          pkgs.colmena
        ];
      };

      packages = let
        name = "bootstrap";
        modules = [
          ./common
          (with pkgs; {
            networking = {
              hostName = name;
              domain = "bootstrap.fap.no";
              firewall.enable = lib.mkForce false;
            };
          })
        ];
      in {
        # nix build --system aarch64-linux .#name
        "rpi4" =
          nixos-generators.nixosGenerate
          {
            system = "aarch64-linux";
            modules =
              [
                # FIX: this is requried to build the RPi kernel:
                # https://github.com/NixOS/nixpkgs/issues/154163
                # https://github.com/NixOS/nixos-hardware/issues/360
                {
                  nixpkgs.overlays = [
                    (final: super: {
                      makeModulesClosure = x:
                        super.makeModulesClosure (x // {allowMissing = true;});
                    })
                  ];
                }
                {
                  boot.kernelPackages = pkgs.lib.mkForce pkgs.linuxPackages_rpi4;
                }
                {
                  networking = {
                    # wireless = {
                    #   enable = true;
                    #   interfaces = ["wlan0"];
                    #   networks = {
                    #     "<Insert SSID>" = {
                    #       psk = "";
                    #     };
                    #   };
                    # };
                    # interfaces.wlan0.useDHCP = true;
                    interfaces.eth0.useDHCP = true;
                  };
                }
                ./common/rpi4-configuration.nix
              ]
              ++ modules;
            specialArgs = {inherit flakes;};
            format = "sd-aarch64";
          };
        "nanopi-neo2" =
          nixos-generators.nixosGenerate
          {
            system = "aarch64-linux";
            modules =
              [
                # FIX: this is requried to build the RPi kernel:
                # https://github.com/NixOS/nixpkgs/issues/154163
                # https://github.com/NixOS/nixos-hardware/issues/360
                # {
                #   nixpkgs.overlays = [
                #     (final: super: {
                #       makeModulesClosure = x:
                #         super.makeModulesClosure (x // {allowMissing = true;});
                #     })
                #   ];
                # }
                {
                  networking = {
                    interfaces.eth0.useDHCP = true;
                  };
                }
                ./misc/nanopi-neo2
              ]
              ++ modules;
            specialArgs = {inherit flakes;};
            format = "sd-aarch64";
          };
        "vmware" =
          nixos-generators.nixosGenerate
          {
            inherit system;
            inherit modules;
            specialArgs = {inherit flakes;};
            format = "vmware";
          };
        "iso" =
          nixos-generators.nixosGenerate
          {
            inherit system;
            inherit modules;
            specialArgs = {inherit flakes;};
            format = "install-iso";
          };
      };
    });
}
