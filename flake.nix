{
  description = "kradalby's system config";

  # nixConfig = {
  #   extra-substituters = [
  #     # "http://attic.dalby.ts.net/system?priority=43"
  #   ];
  #   extra-trusted-public-keys = [
  #     # "system:40arGOg81ZACFJQAksoEplo8PfgxDd6aEQpNbuHXcCg="
  #   ];
  # };

  inputs = {
    utils.url = "github:numtide/flake-utils";

    nixpkgs.url = "github:NixOS/nixpkgs/release-25.11";
    nixpkgs-nixos.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-25.11-darwin";
    # nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-old-stable.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    nixpkgs-kradalby.url = "github:kradalby/nixpkgs/headscale-026";

    nixpkgs-hardware.url = "github:NixOS/nixos-hardware";

    darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-25.11";
    darwin.inputs.nixpkgs.follows = "nixpkgs-darwin";

    darwin-unstable.url = "github:nix-darwin/nix-darwin";
    darwin-unstable.inputs.nixpkgs.follows = "nixpkgs-unstable";

    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    home-manager-unstable.url = "github:nix-community/home-manager/master";
    home-manager-unstable.inputs.nixpkgs.follows = "nixpkgs-unstable";

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs-nixos";
    };

    microvm = {
      url = "github:astro/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs-nixos";
    };

    nix-rosetta-builder = {
      url = "github:cpick/nix-rosetta-builder";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    ragenix = {
      url = "github:yaxitech/ragenix";
      inputs."flake-utils".follows = "utils";
      inputs.nixpkgs.follows = "nixpkgs";
      # inputs."agenix".inputs."nixpkgs".follows = "nixpkgs";
    };

    jujutsu = {
      url = "github:jj-vcs/jj";
      inputs."flake-utils".follows = "utils";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      # inputs."agenix".inputs."nixpkgs".follows = "nixpkgs";
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
      # url = "github:juanfont/headscale/v0.26.0-beta.1";
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
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    tsidp = {
      url = "github:tailscale/tsidp";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    tailscale = {
      url = "github:tailscale/tailscale/v1.90.6";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    ssh-agent-mux = {
      url = "github:kradalby/ssh-agent-mux";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # munin.url = "github:kradalby/munin";
    neovim-kradalby = {
      url = "github:kradalby/neovim";
      inputs."flake-utils".follows = "utils";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    nefit-homekit = {
      url = "github:kradalby/nefit-homekit";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      inputs."flake-utils".follows = "utils";
    };

    tasmota-homekit = {
      url = "github:kradalby/tasmota-homekit";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      inputs."flake-utils".follows = "utils";
    };

    z2m-homekit = {
      url = "github:kradalby/z2m-homekit";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      inputs."flake-utils".follows = "utils";
    };

  };

  outputs = {
    self,
    nixpkgs-nixos,
    nixpkgs-darwin,
    darwin,
    home-manager,
    nixos-generators,
    utils,
    ...
  } @ inputs: let
    overlay-pkgs = final: _: {
      stable = import nixpkgs-nixos {
        inherit (final) system;
        config = {
          allowUnfree = true;
        };
        overlays = [(import ./pkgs/overlays {})];
      };
      old-stable = import inputs.nixpkgs-old-stable {
        inherit (final) system;
        config = {allowUnfree = true;};
        overlays = [
          (import ./pkgs/overlays {})
        ];
      };
      unstable = import inputs.nixpkgs-unstable {
        inherit (final) system;
        config = {allowUnfree = true;};
        overlays = [
          (import ./pkgs/overlays {})
          (
            _: final: {
              # gopls = final.gopls.override {
              #   buildGoModule = final.buildGo124Module;
              # };
            }
          )
        ];
      };
      master = import inputs.nixpkgs-master {
        inherit (final) system;
        config = {allowUnfree = true;};
        overlays = [
          (
            _: final: {
              # gopls = final.gopls.override {
              #   buildGoModule = final.buildGo124Module;
              # };
            }
          )
        ];
      };
    };

    overlays = with inputs; [
      overlay-pkgs
      ragenix.overlays.default
      jujutsu.overlays.default
      headscale.overlay
      # hugin.overlay
      # munin.overlay
      golink.overlays.default
      (import ./pkgs/overlays {})
      (_: final: let
        # TODO(kradalby): figure out why this doesnt work
        goOver = name: ("${name}".packages."${final.system}"."${name}".override {
          buildGoModule = final.buildGo124Module;
        });
      in {
        go = final.go_1_24;
        buildGoModules = final.buildGo124Modules;
        hugin = hugin.packages."${final.system}".hugin.override {
          buildGoModule = final.buildGo124Module;
        };
        krapage = krapage.packages."${final.system}".krapage.override {
          buildGoModule = final.buildGo124Module;
        };
        hvor = hvor.packages."${final.system}".hvor.override {
          buildGoModule = final.buildGo124Module;
        };
        tasmota-exporter = tasmota-exporter.packages."${final.system}".tasmota-exporter.override {
          buildGoModule = final.buildGo124Module;
        };
        homewizard-p1-exporter = homewizard-p1-exporter.packages."${final.system}".homewizard-p1-exporter.override {
          buildGoModule = final.buildGo124Module;
        };
        redlib = redlib.packages."${final.system}".default;
        neovim = neovim-kradalby.packages."${final.system}".neovim-kradalby;
        tailscale = tailscale.packages."${final.system}".tailscale;
        ssh-agent-mux = inputs.ssh-agent-mux.packages."${final.system}".default;
        nefit-homekit = inputs.nefit-homekit.packages."${final.system}".default;
        tasmota-homekit = inputs.tasmota-homekit.packages."${final.system}".default;
        z2m-homekit = inputs.z2m-homekit.packages."${final.system}".default;
      })
    ];

    lib = nixpkgs-nixos.lib.extend (
      final: _: {
        k = import ./k.nix {};
      }
    );

    box = import ./lib/box.nix {
      pkgs = nixpkgs-nixos;
      inherit inputs overlays lib;
      rev = nixpkgs-nixos.lib.mkIf (self ? rev) self.rev;
    };
  in
    {
      nixosConfigurations = {
        # "core.terra" = box.nixosBox {
        #   arch = "x86_64-linux";
        #   name = "core.terra";
        #   tags = ["x86" "router" "terra"];
        #   modules = with inputs; [
        #     hugin.nixosModules.default
        #   ];
        # };

        "core.oracldn" = box.nixosBox {
          arch = "aarch64-linux";
          name = "core.oracldn";
          tags = ["arm64" "oracle" "oracldn"];
          modules = with inputs; [
            headscale.nixosModules.default
            golink.nixosModules.default
            krapage.nixosModules.default
            hvor.nixosModules.default
            tasmota-exporter.nixosModules.default
            homewizard-p1-exporter.nixosModules.default
          ];
        };

        "dev.oracfurt" = box.nixosBox {
          arch = "aarch64-linux";
          name = "dev.oracfurt";
          tags = ["arm64" "oracle" "oracfurt"];
          modules = with inputs; [
            tsidp.nixosModules.default
          ];
        };

        "home.ldn" = box.nixosBox {
          arch = "x86_64-linux";
          name = "home.ldn";
          tags = ["x86" "ldn"];
          targetHost = "10.65.0.26";
          modules = with inputs; [
            nefit-homekit.nixosModules.default
            tasmota-homekit.nixosModules.default
            z2m-homekit.nixosModules.default
          ];
        };

        # "rpi.vetle" = box.nixosBox {
        #   arch = "aarch64-linux";
        #   name = "home.ldn";
        #   tags = ["arm64" "ldn"];
        # };

        "dev.ldn" = box.nixosBox {
          arch = "x86_64-linux";
          homeBase = home-manager;
          name = "dev.ldn";
          tags = ["x86" "ldn"];
          targetHost = "10.65.0.27";
        };

        "storage.ldn" = box.nixosBox {
          arch = "x86_64-linux";
          name = "storage.ldn";
          tags = ["x86" "ldn"];
          targetHost = "10.65.0.28";
        };

        "lenovo.ldn" = box.nixosBox {
          arch = "x86_64-linux";
          name = "lenovo.ldn";
          tags = ["x86" "ldn"];
        };

        "core.tjoda" = box.nixosBox {
          arch = "x86_64-linux";
          name = "core.tjoda";
          tags = ["x86" "router" "tjoda"];
        };
      };

      # darwin-rebuild switch --flake .#kramacbook
      darwinConfigurations = {
        kratail2 = let
          machine = {
            arch = "aarch64-darwin";
            username = "kradalby";
            hostname = "kratail2";
            homeDir = /Users/kradalby;
          };
        in
          box.macBox machine darwin home-manager [
            inputs.ssh-agent-mux.darwinModules.default
            inputs.nix-rosetta-builder.darwinModules.default
          ];

        krair = let
          machine = {
            arch = "aarch64-darwin";
            username = "kradalby";
            hostname = "krair";
            homeDir = /Users/kradalby;
          };
        in
          box.macBox machine darwin home-manager [
            inputs.ssh-agent-mux.darwinModules.default
            inputs.nix-rosetta-builder.darwinModules.default
          ];
      };

      colmena = box.mkColmenaFromNixOSConfigurations self.nixosConfigurations;
    }
    // utils.lib.eachDefaultSystem
    (system: let
      pkgs = import nixpkgs-nixos {
        inherit overlays;
        inherit system;
      };
    in {
      devShell = let
        hostNames = builtins.attrNames self.nixosConfigurations;
      in
        pkgs.mkShell {
          buildInputs = [
            pkgs.alejandra
            pkgs.unstable.prek
            pkgs.nodePackages.prettier
            pkgs.shfmt
            pkgs.colmena
            pkgs.webrepl_cli

            (pkgs.writeShellScriptBin
              "ship"
              ''
                #!/usr/bin/env bash
                set -euo pipefail

                # Host list from nixosConfigurations
                hosts=(${builtins.concatStringsSep " " hostNames})
                target_hosts=("''${hosts[@]}")

                if [ $# -eq 1 ]; then
                    if [[ " ''${hosts[*]} " =~ " $1 " ]]; then
                        target_hosts=("$1")
                    else
                        echo "Error: '$1' is not a valid host. Choose from: ''${hosts[*]}"
                        exit 1
                    fi
                fi

                for host in "''${target_hosts[@]}"; do
                    echo "Shipping to $host..."
                    rsync -ah --delete --cvs-exclude --filter=':- .gitignore' . "root@$host:/etc/nixos/."
                done
              '')
          ];
        };

      packages = let
        name = "bootstrap";
        modules = [
          inputs.ragenix.nixosModules.age
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
