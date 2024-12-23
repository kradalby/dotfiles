{
  description = "kradalby's system config";

  inputs = {
    utils.url = "github:numtide/flake-utils";

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-old-stable.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    nixpkgs-kradalby.url = "github:kradalby/nixpkgs/kradalby/headscale-023";

    nixpkgs-hardware.url = "github:NixOS/nixos-hardware";

    darwin.url = "github:lnl7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    darwin-unstable.url = "github:lnl7/nix-darwin";
    darwin-unstable.inputs.nixpkgs.follows = "nixpkgs-unstable";

    home-manager.url = "github:nix-community/home-manager/release-24.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    home-manager-unstable.url = "github:nix-community/home-manager/master";
    home-manager-unstable.inputs.nixpkgs.follows = "nixpkgs-unstable";

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-rosetta-builder = {
      url = "github:cpick/nix-rosetta-builder";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dream2nix = {
      url = "github:nix-community/dream2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs."flake-utils".follows = "utils";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ragenix = {
      url = "github:yaxitech/ragenix";
      inputs."flake-utils".follows = "utils";
      inputs.nixpkgs.follows = "nixpkgs";
      # inputs."agenix".inputs."nixpkgs".follows = "nixpkgs";
    };

    sql-studio = {
      url = "github:frectonz/sql-studio";
      inputs."flake-utils".follows = "utils";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    redlib = {
      url = "github:redlib-org/redlib/6c64ebd56b98f5616c2014e2e0567fa37791844c";
      # url = "github:redlib-org/redlib";
      # inputs."flake-utils".follows = "utils";
      # inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # Go based
    krapage = {
      url = "github:kradalby/kra";
      inputs."utils".follows = "utils";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    hvor = {
      url = "github:kradalby/hvor";
      inputs."utils".follows = "utils";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    tasmota-exporter = {
      url = "github:kradalby/tasmota-exporter";
      inputs."utils".follows = "utils";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    homewizard-p1-exporter = {
      url = "github:kradalby/homewizard-p1-exporter";
      inputs."utils".follows = "utils";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    headscale = {
      # url = "github:juanfont/headscale/v0.24.0-beta.2";
      url = "github:juanfont/headscale/main";
      inputs."flake-utils".follows = "utils";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    hugin = {
      url = "github:kradalby/hugin";
      inputs."flake-utils".follows = "utils";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    golink = {
      url = "github:tailscale/golink";
      inputs."flake-utils".follows = "utils";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # munin.url = "github:kradalby/munin";
    neovim-kradalby = {
      url = "github:kradalby/neovim";
      inputs."flake-utils".follows = "utils";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-old-stable,
    nixpkgs-unstable,
    nixpkgs-master,
    nixpkgs-kradalby,
    darwin,
    home-manager,
    ragenix,
    sql-studio,
    redlib,
    nixos-generators,
    nix-rosetta-builder,
    dream2nix,
    vscode-extensions,
    flake-utils,
    headscale,
    hugin,
    # munin,
    golink,
    neovim-kradalby,
    krapage,
    hvor,
    tasmota-exporter,
    homewizard-p1-exporter,
    ...
  } @ inputs: let
    overlay-pkgs = final: _: {
      stable = import nixpkgs {
        inherit (final) system;
        config = {
          allowUnfree = true;
        };
        overlays = [(import ./pkgs/overlays {})];
      };
      old-stable = import nixpkgs-old-stable {
        inherit (final) system;
        config = {allowUnfree = true;};
        overlays = [
          (import ./pkgs/overlays {})
          (
            _: final: {
              gopls = final.gopls.override {
                buildGoModule = final.buildGo123Module;
              };
            }
          )
        ];
      };
      unstable = import nixpkgs-unstable {
        inherit (final) system;
        config = {allowUnfree = true;};
        overlays = [
          (import ./pkgs/overlays {})
          (
            _: final: {
              gopls = final.gopls.override {
                buildGoModule = final.buildGo123Module;
              };
            }
          )
        ];
      };
      master = import nixpkgs-master {
        inherit (final) system;
        config = {allowUnfree = true;};
        overlays = [
          (
            _: final: {
              gopls = final.gopls.override {
                buildGoModule = final.buildGo123Module;
              };
            }
          )
        ];
      };
    };

    overlays = [
      overlay-pkgs
      ragenix.overlays.default
      headscale.overlay
      # hugin.overlay
      # munin.overlay
      golink.overlay
      vscode-extensions.overlays.default
      (import ./pkgs/overlays {})
      (_: final: let
        # TODO(kradalby): figure out why this doesnt work
        goOver = name: ("${name}".packages."${final.system}"."${name}".override {
          buildGoModule = final.buildGo123Module;
        });
      in {
        go = final.go_1_23;
        buildGoModules = final.buildGo123Modules;
        hugin = hugin.packages."${final.system}".hugin.override {
          buildGoModule = final.buildGo123Module;
        };
        krapage = krapage.packages."${final.system}".krapage.override {
          buildGoModule = final.buildGo123Module;
        };
        hvor = hvor.packages."${final.system}".hvor.override {
          buildGoModule = final.buildGo123Module;
        };
        tasmota-exporter = tasmota-exporter.packages."${final.system}".tasmota-exporter.override {
          buildGoModule = final.buildGo123Module;
        };
        homewizard-p1-exporter = homewizard-p1-exporter.packages."${final.system}".homewizard-p1-exporter.override {
          buildGoModule = final.buildGo123Module;
        };
        sql-studio = sql-studio.packages."${final.system}".default;
        redlib = redlib.packages."${final.system}".default;
        neovim = neovim-kradalby.packages."${final.system}".neovim-kradalby;
      })
    ];
  in
    {
      lib = nixpkgs-unstable.lib.extend (
        final: _: {
          box = import ./lib/box.nix {
            pkgs = nixpkgs;
            inherit inputs overlays;
          };
        }
      );

      nixosConfigurations = {
        "core.terra" = self.lib.box.nixosBox {
          arch = "x86_64-linux";
          name = "core.terra";
          tags = ["x86" "router" "terra"];
          modules = [
            hugin.nixosModules.default
          ];
        };

        "core.oracldn" = self.lib.box.nixosBox {
          arch = "aarch64-linux";
          name = "core.oracldn";
          tags = ["arm64" "oracle" "oracldn"];
          modules = [
            golink.nixosModules.default
            krapage.nixosModules.default
            hvor.nixosModules.default
            tasmota-exporter.nixosModules.default
            homewizard-p1-exporter.nixosModules.default
          ];
        };

        "dev.oracfurt" = self.lib.box.nixosBox {
          arch = "aarch64-linux";
          name = "dev.oracfurt";
          tags = ["arm64" "oracle" "oracfurt"];
        };

        "home.ldn" = self.lib.box.nixosBox {
          arch = "aarch64-linux";
          name = "home.ldn";
          tags = ["arm64" "ldn"];
        };

        "rpi.vetle" = self.lib.box.nixosBox {
          arch = "aarch64-linux";
          name = "home.ldn";
          tags = ["arm64" "ldn"];
        };

        "dev.ldn" = self.lib.box.nixosBox {
          arch = "x86_64-linux";
          homeBase = home-manager;
          name = "dev.ldn";
          tags = ["x86" "ldn"];
        };

        "core.tjoda" = self.lib.box.nixosBox {
          arch = "x86_64-linux";
          name = "core.tjoda";
          tags = ["x86" "router" "tjoda"];
        };
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
          self.lib.box.macBox machine darwin home-manager;

        kratail2 = let
          machine = {
            arch = "aarch64-darwin";
            username = "kradalby";
            hostname = "kratail2";
            homeDir = /Users/kradalby;
          };
        in
          self.lib.box.macBox machine darwin home-manager;

        kraairm2 = let
          machine = {
            arch = "aarch64-darwin";
            username = "kradalby";
            hostname = "kraairm2";
            homeDir = /Users/kradalby;
          };
        in
          self.lib.box.macBox machine darwin home-manager;
      };

      colmena = self.lib.box.mkColmenaFromNixOSConfigurations self.nixosConfigurations;
    }
    // flake-utils.lib.eachDefaultSystem
    (system: let
      pkgs = import nixpkgs {
        inherit overlays;
        inherit system;
      };
    in {
      devShell = pkgs.mkShell {
        buildInputs = [
          pkgs.alejandra
          pkgs.colmena
          pkgs.webrepl_cli
        ];
      };

      packages = let
        name = "bootstrap";
        modules = [
          ragenix.nixosModules.age
          ./common
          ./common/tailscale.nix
          (with pkgs; {
            networking = {
              hostName = name;
              domain = "bootstrap.fap.no";
              firewall.enable = lib.mkForce false;
              useDHCP = lib.mkForce true;
            };

            services.tailscale = let
              authKey = pkgs.writeText "authkey" "";
            in {
              authKeyFile = pkgs.lib.mkForce authKey;
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
                    (_: super: {
                      makeModulesClosure = x:
                        super.makeModulesClosure (x // {allowMissing = true;});
                    })
                  ];
                }
                {
                  boot.kernelPackages = pkgs.lib.mkForce pkgs.linuxPackages_rpi4;

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
                  };
                }
                ./common/rpi4-configuration.nix
              ]
              ++ modules;
            specialArgs = {inherit inputs;};
            format = "sd-aarch64";
          };
      };
    });
}
