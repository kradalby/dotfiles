{
  description = "kradalby's system config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-23.05-darwin";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nixpkgs-hardware.url = "github:NixOS/nixos-hardware";

    nixpkgs-unifi.url = "github:NixOS/nixpkgs/12bdeb01ff9e2d3917e6a44037ed7df6e6c3df9d";

    darwin.url = "github:lnl7/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs-darwin";

    darwin-unstable.url = "github:lnl7/nix-darwin/master";
    darwin-unstable.inputs.nixpkgs.follows = "nixpkgs-unstable";

    home-manager.url = "github:nix-community/home-manager/release-23.05";
    home-manager-unstable.url = "github:nix-community/home-manager/master";
    home-manager-unstable.inputs.nixpkgs.follows = "nixpkgs-unstable";

    vscode-extensions.url = "github:nix-community/nix-vscode-extensions";

    nur.url = "github:nix-community/NUR";

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    utils.url = "github:numtide/flake-utils";

    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Rust based
    nixinit = {
      url = "github:nix-community/nix-init";
      inputs.fenix.follows = "fenix";
    };

    ragenix = {
      url = "github:yaxitech/ragenix";
      inputs."flake-utils".follows = "utils";
    };

    krapage = {
      url = "github:kradalby/kra";
      inputs."utils".follows = "utils";
    };

    hvor = {
      url = "github:kradalby/hvor";
      inputs."utils".follows = "utils";
    };

    # Go based
    headscale.url = "github:juanfont/headscale";
    # headscale.url = "github:kradalby/headscale/1561-online-issue";
    hugin.url = "github:kradalby/hugin";
    golink.url = "github:tailscale/golink";

    munin.url = "github:kradalby/munin";
    devenv.url = "github:cachix/devenv/latest";
    neovim-kradalby.url = "github:kradalby/neovim";
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-unstable,
    darwin,
    home-manager,
    ragenix,
    vscode-extensions,
    nur,
    fenix,
    nixos-generators,
    flake-utils,
    headscale,
    hugin,
    munin,
    golink,
    nixinit,
    devenv,
    neovim-kradalby,
    krapage,
    hvor,
    ...
  } @ flakes: let
    overlay-pkgs = final: _: {
      stable = import nixpkgs {inherit (final) system;};
      unstable = import nixpkgs-unstable {inherit (final) system;};
      unifi = import flakes.nixpkgs-unifi {inherit (final) system;};
    };

    overlays = [
      nur.overlay
      overlay-pkgs
      fenix.overlays.default
      ragenix.overlays.default
      headscale.overlay
      hugin.overlay
      munin.overlay
      golink.overlay
      vscode-extensions.overlays.default
      (import ./pkgs/overlays {})
      (_: prev: {
        inherit (devenv.packages."${prev.system}") devenv;
        inherit (krapage.packages."${prev.system}") krapage;
        inherit (hvor.packages."${prev.system}") hvor;
        nix-init = nixinit.packages."${prev.system}".default;
        neovim = neovim-kradalby.packages."${prev.system}".neovim-kradalby;
      })
    ];

    commonModules = pkgBase: [
      ragenix.nixosModules.age

      {
        nixpkgs.overlays = overlays;
      }
      {
        # pin system nixpkgs to the same version as the flake input
        # (don't see a way to declaratively set channels but this seems to work fine?)
        nix.nixPath = ["nixpkgs=${pkgBase}"];
      }
    ];

    nixosBox = arch: pkgBase: homeBase: name:
      pkgBase.lib.nixosSystem {
        system = arch;
        modules =
          (commonModules pkgBase)
          ++ [
            hugin.nixosModules.default
            golink.nixosModules.default
            krapage.nixosModules.default
            hvor.nixosModules.default
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

    macBox = machine: pkgBase: homeBase:
      pkgBase.lib.darwinSystem {
        system = machine.arch;
        modules =
          (commonModules pkgBase)
          ++ [
            (./. + "/machines/${machine.hostname}")
            homeBase.darwinModules.home-manager
          ];
        specialArgs = {
          inherit flakes;
          inherit machine;
        };
      };

    # homeOnly = machine: pkgBase: homeBase:
    #   homeBase.lib.homeManagerConfiguration {
    #     inherit (machine) username;
    #     system = machine.arch;
    #     homeDirectory = machine.homeDir;
    #     configuration.imports = [ ./home ];
    #     extraModules =
    #       (commonModules pkgBase)
    #       ++ [
    #         (./. + "/machines/${machine.hostname}")
    #       ];
    #   };

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
      // (builtins.mapAttrs
        (name: value: {
          deployment = {
            buildOnTarget = false;
            # Replace hostname with tailscale hostname to use tailscale auth.
            targetHost = builtins.replaceStrings ["."] ["-"] name;
          };
          nixpkgs.system = value.config.nixpkgs.system;
          imports = value._module.args.modules;
        })
        nixosConfigurations);
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
        "dev.ldn" = nixosBox "x86_64-linux" nixpkgs home-manager "dev.ldn";

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

      # homeConfigurations = {
      #   # nix run github:nix-community/home-manager/master --no-write-lock-file -- switch --flake .#multipass
      #   "kradalby" =
      #     let
      #       machine = {
      #         arch = "x86_64-linux";
      #         username = "kradalby";
      #         hostname = "kradalby.home";
      #         homeDir = "/home/kradalby";
      #       };
      #     in
      #     homeOnly machine home-manager;
      # };

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
