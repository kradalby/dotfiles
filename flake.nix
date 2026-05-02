{
  description = "kradalby's system config";

  nixConfig = {
    extra-substituters = [
      "https://nixos-raspberrypi.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
  };

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

    paseo = {
      url = "github:getpaseo/paseo";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # Stock nixpkgs sd-image-aarch64 has no Pi5 support (no bcm2712 DTB,
    # u-boot, or [pi5] config.txt). nixos-raspberrypi ships proper Pi5
    # firmware + sd-image generator.
    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main";
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
        # Upstream Nix build is broken (prettier missing from node_modules
        # due to --filter excluding root devDeps). Use prebuilt binaries.
        opencode = let
          version = "1.14.19";
          srcs = {
            x86_64-linux = {
              url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-linux-x64-baseline.tar.gz";
              hash = "sha256-N1D1Hf40e+l+qnasnFJX64Wmb+bdSyeES0YcQlKJjgM=";
            };
            aarch64-darwin = {
              url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-darwin-arm64.zip";
              hash = "sha256-VUogGSJVFPZp4bAUSCouJ8fnKcMzcCAwFRDzK+cWIpA=";
            };
          };
          src = prev.fetchurl srcs.${system};
        in
          prev.stdenv.mkDerivation {
            pname = "opencode";
            inherit version src;
            nativeBuildInputs =
              prev.lib.optional prev.stdenv.hostPlatform.isLinux [prev.autoPatchelfHook]
              ++ prev.lib.optional (prev.lib.hasSuffix ".zip" srcs.${system}.url) [prev.unzip];
            sourceRoot = ".";
            unpackPhase =
              if prev.lib.hasSuffix ".tar.gz" srcs.${system}.url
              then "tar xzf $src"
              else "unzip $src";
            dontStrip = true; # bun standalone binaries append JS payload to ELF
            installPhase = ''
              install -Dm755 opencode $out/bin/opencode
            '';
            meta.mainProgram = "opencode";
          };

        # lima 1.2.2 in stable branches is marked insecure/EOL.
        # Override so transitive consumers (nix-rosetta-builder)
        # get the unstable version.
        inherit (prev.unstable) lima lima-full;

        # fish 4.2.1 in darwin-25.11 hangs on startup (aarch64).
        # Use the unstable version until the fix lands in stable.
        inherit (prev.unstable) fish;

        # direnv 2.37.1's bash test suite hangs on darwin because some
        # test scenarios contain literal backspace/CR characters in
        # directory names which trip up macOS filesystem ops. Skip the
        # check phase on darwin until upstream fixes this.
        direnv = prev.direnv.overrideAttrs (_old:
          prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
            doCheck = false;
          });
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

        "rpi5.ldn" = box.nixosBox {
          arch = "aarch64-linux";
          name = "rpi5.ldn";
          tags = ["arm64" "ldn"];
          # LAN IP for the first deploy before the host joins
          # tailscale. Drop to null once rpi5-ldn.<tailnet> resolves.
          # targetHost = "10.65.0.196";
          modules = with inputs; [
            # raspberry-pi-5 modules consume nixos-raspberrypi as a
            # module argument (normally set by the flake's own
            # lib.nixosSystem via specialArgs). box.nixosBox calls
            # plain nixpkgs.lib.nixosSystem so we wire the arg in.
            ({...}: {_module.args.nixos-raspberrypi = nixos-raspberrypi;})
            nixos-raspberrypi.nixosModules.raspberry-pi-5.base
            nixos-raspberrypi.nixosModules.raspberry-pi-5.page-size-16k
            nixos-raspberrypi.nixosModules.nixpkgs-rpi
            nixos-raspberrypi.nixosModules.trusted-nix-caches
            ({...}: {
              nixpkgs.overlays = [
                nixos-raspberrypi.overlays.bootloader
                nixos-raspberrypi.overlays.vendor-kernel
                nixos-raspberrypi.overlays.vendor-firmware
                nixos-raspberrypi.overlays.kernel-and-firmware
                nixos-raspberrypi.overlays.vendor-pkgs
              ];
            })
          ];
        };

        "storage.ldn" = box.nixosBox {
          arch = "x86_64-linux";
          name = "storage.ldn";
          tags = ["x86" "ldn"];
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

      homeConfigurations = {
        "ubuntu@kradalby-llm" = home-manager.lib.homeManagerConfiguration {
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
            pkgs.prettier
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
    // (let
      mkRpiBootstrap = import ./lib/rpi-bootstrap.nix {
        inherit nixos-generators inputs overlays;
      };
      rpiPkgs = import nixpkgs-nixos {
        system = "aarch64-linux";
        inherit overlays;
      };
      allowMissingModulesOverlay = _: super: {
        makeModulesClosure = x:
          super.makeModulesClosure (x // {allowMissing = true;});
      };

      # !!! DO NOT COMMIT SECRETS BELOW !!!
      # Fill locally, run `nix build .#rpi4` or `.#rpi5`, flash image,
      # then `git checkout flake.nix` to revert. Both secrets land in
      # the Nix store / image — treat accordingly.
      bootstrapSecrets = {
        kadPsk = "REPLACE_WIFI_PSK";
        tsAuthKey = "REPLACE_TS_AUTHKEY";
      };

      # Shared module list for the rpi5 nixos-raspberrypi build.
      rpi5Modules = [
        inputs.ragenix.nixosModules.age
        inputs.tailscale.nixosModules.default
        ./common
        ./common/tailscale.nix
        ./common/bootstrap-common.nix
        inputs.nixos-raspberrypi.nixosModules.raspberry-pi-5.base
        inputs.nixos-raspberrypi.nixosModules.raspberry-pi-5.page-size-16k
        inputs.nixos-raspberrypi.nixosModules.sd-image
        {
          nixpkgs.overlays = overlays;
          my.bootstrap =
            bootstrapSecrets
            // {
              enable = true;
              name = "bootstrap5";
            };
        }
      ];
    in {
      # Bootstrap SD image for Raspberry Pi 4 (nixpkgs sd-image-aarch64).
      packages.aarch64-linux.rpi4 = mkRpiBootstrap (bootstrapSecrets
        // {
          name = "bootstrap4";
          hardwareModule = ./common/rpi4-configuration.nix;
          extraOverlays = [allowMissingModulesOverlay];
          extraModules = [
            {
              boot.kernelPackages =
                rpiPkgs.lib.mkForce rpiPkgs.linuxPackages_rpi4;
            }
          ];
        });

      # Bootstrap SD image for Raspberry Pi 5 (nixos-raspberrypi).
      # nixosSystemFull pulls the Pi-optimised pkgs overlay (ffmpeg,
      # kodi, libcamera, libpisp). For a headless server that overlay
      # is a no-op since nothing references those packages, so cost is
      # zero and future camera/kodi work gets the optimised variants
      # for free.
      packages.aarch64-linux.rpi5 =
        (inputs.nixos-raspberrypi.lib.nixosSystemFull {
          specialArgs = {inherit inputs;};
          modules = rpi5Modules;
        })
        .config
        .system
        .build
        .sdImage;
    });
}
