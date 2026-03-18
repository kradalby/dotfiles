{
  description = "kradalby's system config";

  inputs = {
    utils.url = "github:numtide/flake-utils";

    nixpkgs-nixos.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-25.11-darwin";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-25.11";
    darwin.inputs.nixpkgs.follows = "nixpkgs-darwin";

    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs-nixos";
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs-nixos";

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs-nixos";
    };

    nix-rosetta-builder = {
      url = "github:cpick/nix-rosetta-builder";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    ragenix = {
      url = "github:yaxitech/ragenix";
      inputs."flake-utils".follows = "utils";
      inputs.nixpkgs.follows = "nixpkgs-nixos";
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

    golink = {
      url = "github:tailscale/golink";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      inputs.systems.follows = "utils/systems";
    };

    tsidp = {
      url = "github:tailscale/tsidp";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      inputs.systems.follows = "utils/systems";
    };

    tailscale = {
      url = "github:tailscale/tailscale/kradalby/nixos-module";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      inputs.systems.follows = "utils/systems";
      inputs.flake-compat.follows = "";
    };

    ssh-agent-mux = {
      url = "github:kradalby/ssh-agent-mux";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      inputs."flake-utils".follows = "utils";
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

    opencode = {
      url = "github:anomalyco/opencode";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
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
    mkGoOverlay = version: final: prev: {
      go = final."go_${version}";
      buildGoModule = final."buildGo${builtins.replaceStrings ["_"] [""] version}Module";
    };
    goOverlayStable = mkGoOverlay "1_25";
    goOverlayUnstable = mkGoOverlay "1_26";

    overlay-pkgs = final: _: {
      unstable = import inputs.nixpkgs-unstable {
        system = final.stdenv.hostPlatform.system;
        config = {allowUnfree = true;};
        overlays = [goOverlayUnstable (import ./pkgs/overlays {})];
      };
      master = import inputs.nixpkgs-master {
        system = final.stdenv.hostPlatform.system;
        config = {allowUnfree = true;};
        overlays = [goOverlayUnstable];
      };
    };

    overlays = with inputs; [
      overlay-pkgs
      goOverlayStable
      headscale.overlays.default
      golink.overlays.default
      krapage.overlays.default
      hvor.overlays.default
      tasmota-exporter.overlays.default
      homewizard-p1-exporter.overlays.default
      (import ./pkgs/overlays {})
      (_final: prev: let
        system = prev.stdenv.hostPlatform.system;
      in {
        neovim = neovim-kradalby.packages."${system}".neovim-kradalby;
        tailscale = tailscale.packages."${system}".tailscale;
        ssh-agent-mux = inputs.ssh-agent-mux.packages."${system}".default;
        nefit-homekit = inputs.nefit-homekit.packages."${system}".default;
        tasmota-homekit = inputs.tasmota-homekit.packages."${system}".default;
        z2m-homekit = inputs.z2m-homekit.packages."${system}".default;
        opencode = inputs.opencode.packages."${system}".default;

        # lima 1.2.2 in stable branches is marked insecure/EOL.
        # Override so transitive consumers (nix-rosetta-builder)
        # get the unstable version.
        inherit (prev.unstable) lima lima-full;
      })
    ];

    box = import ./lib/box.nix {
      pkgs = nixpkgs-nixos;
      inherit inputs overlays;
      lib = nixpkgs-nixos.lib;
      rev = nixpkgs-nixos.lib.mkIf (self ? rev) self.rev;
    };
  in
    {
      nixosConfigurations = {
        # "core.terra" = box.nixosBox {
        #   arch = "x86_64-linux";
        #   name = "core.terra";
        #   tags = ["x86" "router" "terra"];
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
          allowLocalDeployment = true;
        };

        "storage.ldn" = box.nixosBox {
          arch = "x86_64-linux";
          name = "storage.ldn";
          tags = ["x86" "ldn"];
        };

        # "lenovo.ldn" = box.nixosBox {
        #   arch = "x86_64-linux";
        #   name = "lenovo.ldn";
        #   tags = ["x86" "ldn"];
        # };

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

      homeConfigurations = {
        "kradalby@kradalby-llm" = home-manager.lib.homeManagerConfiguration {
          pkgs = self.nixosConfigurations."dev.ldn".pkgs;
          modules = [
            inputs.nix-index-database.homeModules.nix-index
            ./machines/kradalby-llm
          ];
          extraSpecialArgs = {
            inherit inputs;
          };
        };
      };

      colmena = box.mkColmenaFromNixOSConfigurations self.nixosConfigurations;
    }
    // utils.lib.eachSystem ["x86_64-linux" "aarch64-darwin"]
    (system: let
      pkgs = import nixpkgs-nixos {
        inherit overlays system;
      };
    in {
      formatter = pkgs.alejandra;

      devShells.default = let
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
    })
    // {
      # Bootstrap SD image for Raspberry Pi 4 (aarch64-linux only)
      packages.aarch64-linux.rpi4 = let
        rpiPkgs = import nixpkgs-nixos {
          system = "aarch64-linux";
          inherit overlays;
        };
        name = "bootstrap";
        modules = [
          inputs.ragenix.nixosModules.age
          inputs.tailscale.nixosModules.default
          ./common
          ./common/tailscale.nix
          {
            networking = {
              hostName = name;
              domain = "bootstrap.fap.no";
              firewall.enable = rpiPkgs.lib.mkForce false;
              useDHCP = rpiPkgs.lib.mkForce true;
            };

            services.tailscale = let
              authKey = rpiPkgs.writeText "authkey" "";
            in {
              authKeyFile = rpiPkgs.lib.mkForce authKey;
            };
          }
        ];
      in
        nixos-generators.nixosGenerate {
          system = "aarch64-linux";
          modules =
            [
              {
                nixpkgs.overlays = [
                  (_: super: {
                    makeModulesClosure = x:
                      super.makeModulesClosure (x // {allowMissing = true;});
                  })
                ];
              }
              {
                boot.kernelPackages = rpiPkgs.lib.mkForce rpiPkgs.linuxPackages_rpi4;
              }
              ./common/rpi4-configuration.nix
            ]
            ++ modules;
          specialArgs = {inherit inputs;};
          format = "sd-aarch64";
        };
    };
}
