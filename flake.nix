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
    flake-utils.url = "github:numtide/flake-utils";

    # "stable" tracks the latest NixOS release (26.05) and is the box default.
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
    darwin.inputs.nixpkgs.follows = "nixpkgs-darwin";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs-stable";
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs-stable";

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };

    nix-rosetta-builder = {
      url = "github:cpick/nix-rosetta-builder";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    ragenix = {
      url = "github:yaxitech/ragenix";
      inputs."flake-utils".follows = "flake-utils";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };

    # Go based
    krapage = {
      url = "github:kradalby/kra";
      inputs."flake-utils".follows = "flake-utils";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    hvor = {
      url = "github:kradalby/hvor";
      inputs."flake-utils".follows = "flake-utils";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    tasmota-exporter = {
      url = "github:kradalby/tasmota-exporter";
      inputs."flake-utils".follows = "flake-utils";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    homewizard-p1-exporter = {
      url = "github:kradalby/homewizard-p1-exporter";
      inputs."flake-utils".follows = "flake-utils";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # On the `initial` branch until kradalby/ghdl#1 merges to main.
    ghdl = {
      url = "github:kradalby/ghdl/initial";
      inputs."flake-utils".follows = "flake-utils";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # WIP Nix binary cache served over tailscale; pinned to the `initial` branch.
    tsnixcache = {
      url = "github:kradalby/tsnixcache/initial";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };

    # Self-hosted garnix CI (our fork's integration branch). Update independently
    # with `nix flake update garnix-ci`. Do NOT `follows` nixpkgs: garnix pins
    # nixpkgs-25.11-small + its own nixpkgsUnstable + libkrun for krun; overriding
    # them risks breaking the action-runner.
    garnix-ci.url = "github:kradalby/garnix/integration";

    headscale = {
      # url = "github:juanfont/headscale/v0.26.0-beta.1";
      url = "github:juanfont/headscale/main";
      inputs."flake-utils".follows = "flake-utils";
      # Do NOT follow nixpkgs: headscale pins staging-next-26.05 for go_1_26
      # >= 1.26.4 (GO-2026-5037/5039). nixpkgs-unstable still ships 1.26.3,
      # which fails the go.mod toolchain check. Restore the follows once
      # unstable catches up.
    };

    golink = {
      url = "github:tailscale/golink";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      inputs.systems.follows = "flake-utils/systems";
    };

    # setec-compatible secrets server, pinned to the `initial` branch. Follows
    # nixpkgs-unstable so its go build tracks our toolchain.
    ts1p = {
      url = "github:kradalby/ts1p/initial";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    tsidp = {
      # Pinned to pre-go-1.26.4 commit. Commit 6359a18 bumped go.mod to
      # require >= 1.26.4 but left flake goVersion = "1.26.0", breaking
      # the build. Unpin once the tsidp flake fixes the goVersion mismatch.
      url = "github:tailscale/tsidp/a9340f0d39e46ca47a61f9998d6989e43f0574b0";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      inputs.systems.follows = "flake-utils/systems";
    };

    tailscale = {
      url = "github:tailscale/tailscale/kradalby/nixos-module";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      inputs.systems.follows = "flake-utils/systems";
      inputs.flake-compat.follows = "";
    };

    ssh-agent-mux = {
      url = "github:kradalby/ssh-agent-mux";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      inputs."flake-utils".follows = "flake-utils";
    };

    # munin.url = "github:kradalby/munin";
    neovim-kradalby = {
      url = "github:kradalby/neovim";
      inputs."flake-utils".follows = "flake-utils";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    nefit-homekit = {
      url = "github:kradalby/nefit-homekit";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      inputs."flake-utils".follows = "flake-utils";
    };

    tasmota-homekit = {
      url = "github:kradalby/tasmota-homekit";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      inputs."flake-utils".follows = "flake-utils";
    };

    z2m-homekit = {
      url = "github:kradalby/z2m-homekit";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      inputs."flake-utils".follows = "flake-utils";
    };

    opencode = {
      url = "github:anomalyco/opencode";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # Agent multiplexer (tmux replacement for `ac`). Do NOT `follows` its
    # rust-overlay — the package is built against the toolchain herdr pins.
    herdr = {
      url = "github:ogulcancelik/herdr/v0.7.3";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # Stock nixpkgs sd-image-aarch64 has no Pi5 support (no bcm2712 DTB,
    # u-boot, or [pi5] config.txt). nixos-raspberrypi ships proper Pi5
    # firmware + sd-image generator.
    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main";
    # Follow the fleet nixpkgs (26.05) so the Pi build matches home-manager
    # and the rest of the fleet — its own pin (25.11) lacks lib/services,
    # which home-manager 26.05 needs.
    nixos-raspberrypi.inputs.nixpkgs.follows = "nixpkgs-stable";
  };

  outputs =
    {
      self,
      nixpkgs-stable,
      nixpkgs-darwin,
      darwin,
      home-manager,
      nixos-generators,
      flake-utils,
      ...
    }@inputs:
    let
      # Single go version for the whole fleet (stable, unstable, master).
      # Bump here to move every in-repo go build at once.
      goOverlay =
        let
          version = "1_26";
        in
        final: _prev: {
          go = final."go_${version}";
          buildGoModule = final."buildGo${builtins.replaceStrings [ "_" ] [ "" ] version}Module";
        };

      overlay-pkgs = final: _: {
        unstable = import inputs.nixpkgs-unstable {
          system = final.stdenv.hostPlatform.system;
          config = {
            allowUnfree = true;
          };
          overlays = [
            goOverlay
            (import ./pkgs/overlays { })
          ];
        };
        master = import inputs.nixpkgs-master {
          system = final.stdenv.hostPlatform.system;
          config = {
            allowUnfree = true;
          };
          overlays = [ goOverlay ];
        };
      };

      overlays = with inputs; [
        overlay-pkgs
        goOverlay
        headscale.overlays.default
        golink.overlays.default
        krapage.overlays.default
        hvor.overlays.default
        tasmota-exporter.overlays.default
        homewizard-p1-exporter.overlays.default
        ghdl.overlays.default
        (import ./pkgs/overlays { })
        (
          _final: prev:
          let
            system = prev.stdenv.hostPlatform.system;
          in
          {
            neovim = neovim-kradalby.packages."${system}".neovim-kradalby;
            tailscale = tailscale.packages."${system}".tailscale;
            ssh-agent-mux = inputs.ssh-agent-mux.packages."${system}".default;
            # Direct package (not herdr.overlays.default — that composes
            # rust-overlay and drags rust-bin into pkgs).
            herdr = inputs.herdr.packages."${system}".default;
            # The agent skill (teaches an agent to drive herdr) ships in herdr's
            # source, so pin it straight from the input — updates with `nix flake
            # update herdr`, nothing to vendor or maintain.
            herdr-skill = inputs.herdr + "/SKILL.md";
            nefit-homekit = inputs.nefit-homekit.packages."${system}".default;
            tasmota-homekit = inputs.tasmota-homekit.packages."${system}".default;
            z2m-homekit = inputs.z2m-homekit.packages."${system}".default;
            # Upstream Nix build requires bun >= 1.3.14; nixpkgs-unstable has 1.3.13.
            # Use prebuilt binaries until nixpkgs ships bun 1.3.14+.
            opencode =
              let
                version = "1.16.2";
                srcs = {
                  x86_64-linux = {
                    url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-linux-x64-baseline.tar.gz";
                    hash = "sha256-/jSwR+PU4vbYkfDS07T0SDfvUnHuz9m5iVHlOFfaaeY=";
                  };
                  aarch64-darwin = {
                    url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-darwin-arm64.zip";
                    hash = "sha256-AVhf9NFYIL06h45Lx8rPsep14jbR/tjC9fNZXtyLerU=";
                  };
                };
                src = prev.fetchurl srcs.${system};
              in
              prev.stdenv.mkDerivation {
                pname = "opencode";
                inherit version src;
                nativeBuildInputs =
                  prev.lib.optionals prev.stdenv.hostPlatform.isLinux [ prev.autoPatchelfHook ]
                  ++ prev.lib.optionals (prev.lib.hasSuffix ".zip" srcs.${system}.url) [ prev.unzip ];
                sourceRoot = ".";
                unpackPhase =
                  if prev.lib.hasSuffix ".tar.gz" srcs.${system}.url then "tar xzf $src" else "unzip $src";
                dontStrip = true; # bun standalone binaries append JS payload to ELF
                installPhase = ''
                  install -Dm755 opencode $out/bin/opencode
                '';
                meta.mainProgram = "opencode";
              };

            # fish 4.2.1 in darwin-25.11 hangs on startup (aarch64).
            # Use the unstable version until the fix lands in stable.
            inherit (prev.unstable) fish;

            # direnv 2.37.1's bash test suite hangs on darwin because some
            # test scenarios contain literal backspace/CR characters in
            # directory names which trip up macOS filesystem ops. Skip the
            # check phase on darwin until upstream fixes this.
            direnv = prev.direnv.overrideAttrs (
              _old:
              prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
                doCheck = false;
              }
            );
          }
        )
      ];

      box = import ./lib/box.nix {
        pkgs = nixpkgs-stable;
        inherit inputs overlays;
        lib = nixpkgs-stable.lib;
        rev = nixpkgs-stable.lib.mkIf (self ? rev) self.rev;
      };
    in
    {
      nixosConfigurations =
        let
          hosts = {
            "core.oracldn" = box.nixosBox {
              arch = "aarch64-linux";
              name = "core.oracldn";
              tags = [
                "arm64"
                "oracle"
                "oracldn"
              ];
              modules = with inputs; [
                headscale.nixosModules.default
                golink.nixosModules.default
                krapage.nixosModules.default
                hvor.nixosModules.default
                tasmota-exporter.nixosModules.default
                homewizard-p1-exporter.nixosModules.default
                ghdl.nixosModules.default
              ];
            };

            "dev.oracfurt" = box.nixosBox {
              arch = "aarch64-linux";
              name = "dev.oracfurt";
              tags = [
                "arm64"
                "oracle"
                "oracfurt"
              ];
              modules = with inputs; [
                tsidp.nixosModules.default
              ];
            };

            "home.ldn" = box.nixosBox {
              arch = "x86_64-linux";
              name = "home.ldn";
              tags = [
                "x86"
                "ldn"
              ];
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
              tags = [
                "x86"
                "ldn"
              ];
              allowLocalDeployment = true;
              # Sole builder for the fleet.
              buildOnTarget = true;
            };

            "rpi5.ldn" = box.nixosBox {
              arch = "aarch64-linux";
              # AI tools + userland (home/ai.nix) come with home-manager, same
              # as the other workstation-class hosts. The SD image stays a bare
              # bootstrap; everything above that is deployed here via colmena.
              homeBase = home-manager;
              name = "rpi5.ldn";
              tags = [
                "arm64"
                "ldn"
              ];
              # LAN IP for the first deploy before the host joins
              # tailscale. Drop to null once rpi5-ldn.<tailnet> resolves.
              # targetHost = "10.65.0.196";
              modules = with inputs; [
                # raspberry-pi-5 modules consume nixos-raspberrypi as a
                # module argument (normally set by the flake's own
                # lib.nixosSystem via specialArgs). box.nixosBox calls
                # plain nixpkgs.lib.nixosSystem so we wire the arg in.
                ({ ... }: { _module.args.nixos-raspberrypi = nixos-raspberrypi; })
                nixos-raspberrypi.nixosModules.raspberry-pi-5.base
                nixos-raspberrypi.nixosModules.raspberry-pi-5.page-size-16k
                nixos-raspberrypi.nixosModules.nixpkgs-rpi
                nixos-raspberrypi.nixosModules.trusted-nix-caches
                (
                  { ... }:
                  {
                    nixpkgs.overlays = [
                      nixos-raspberrypi.overlays.bootloader
                      nixos-raspberrypi.overlays.vendor-kernel
                      nixos-raspberrypi.overlays.vendor-firmware
                      nixos-raspberrypi.overlays.kernel-and-firmware
                      nixos-raspberrypi.overlays.vendor-pkgs
                    ];
                  }
                )
              ];
            };

            "storage.ldn" = box.nixosBox {
              arch = "x86_64-linux";
              name = "storage.ldn";
              tags = [
                "x86"
                "ldn"
              ];
            };

            "ts1p.ldn" = box.nixosBox {
              arch = "x86_64-linux";
              name = "ts1p.ldn";
              tags = [
                "x86"
                "ldn"
              ];
              # Small VM: build on the deployer, not the target.
              buildOnTarget = false;
              modules = with inputs; [
                ts1p.nixosModules.default
              ];
            };

            # Out of rotation.
            # "lenovo.ldn" = box.nixosBox {
            #   arch = "x86_64-linux";
            #   name = "lenovo.ldn";
            #   tags = ["x86" "ldn"];
            # };

            "core.tjoda" = box.nixosBox {
              arch = "x86_64-linux";
              name = "core.tjoda";
              tags = [
                "x86"
                "router"
                "tjoda"
              ];
            };

            # gigabuilder: bare-metal Incus VM host + tsnixcache cache.
            "gigabuilder" = box.nixosBox {
              arch = "x86_64-linux";
              name = "gigabuilder";
              tags = [
                "x86"
                "builder"
              ];
              # No upstream builder to offload to, so build on the target (32 cores).
              buildOnTarget = true;
              # Deploys reach it by tailnet name; uncomment to bootstrap by IP.
              # targetHost = "194.32.107.146";
              modules = with inputs; [
                tsnixcache.nixosModules.tsnixcache
              ];
            };

            # garnix CI: Incus VM on gigabuilder; the host is its remote nix builder.
            "garnix" = box.nixosBox {
              arch = "x86_64-linux";
              name = "garnix";
              tags = [
                "x86"
                "ci"
                "builder"
              ];
              # Deploys reach it by tailnet name; uncomment to bootstrap by IP.
              # targetHost = "10.68.10.10";
            };
          };
        in
        # garnix's attribute matcher is dot-delimited, so it can't build
        # nixosConfigurations whose names contain '.'. Duplicate each host
        # under a dot-free key (dev.ldn -> dev-ldn) so garnix builds them.
        # Dotted originals stay canonical for colmena/deploy; the dupes are
        # filtered back out of colmena below. Drop once garnix handles
        # dotted/quoted names (see home/fish.nix TODO).
        hosts
        // builtins.listToAttrs (
          map (n: {
            name = builtins.replaceStrings [ "." ] [ "-" ] n;
            value = hosts.${n};
          }) (builtins.attrNames hosts)
        );

      # darwin-rebuild switch --flake .#kramacbook
      darwinConfigurations = {
        kratail2 =
          let
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
            inputs.tailscale.darwinModules.default
          ];

        krair =
          let
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

      # Deploy each host once: drop the dot-free dupes garnix needs (dev.ldn ->
      # dev-ldn), i.e. any name that is the de-dotted form of a dotted host.
      colmena = box.mkColmenaFromNixOSConfigurations (
        let
          cfgs = self.nixosConfigurations;
          isDupe =
            name:
            builtins.any (
              n: nixpkgs-stable.lib.hasInfix "." n && builtins.replaceStrings [ "." ] [ "-" ] n == name
            ) (builtins.attrNames cfgs);
        in
        nixpkgs-stable.lib.filterAttrs (name: _: !isDupe name) cfgs
      );
    }
    // flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-darwin" ] (
      system:
      let
        pkgs = import nixpkgs-stable {
          inherit overlays system;
          # prettier builds via the EOL pnpm_9 (build-time only); the system-level
          # allow in common/nix.nix doesn't reach this pkgs import.
          # See NixOS/nixpkgs#529285.
          config.permittedInsecurePackages = [ "pnpm-9.15.9" ];
        };

        # Single formatter entrypoint (`nix fmt` / the treefmt devShell binary).
        # prettier + shfmt are custom formatters pinned to the exact args the old
        # per-tool hooks used (prettier: markdown only; shfmt: -i 2 -ci), so
        # switching to treefmt reformats nothing.
        treefmtEval = inputs.treefmt-nix.lib.evalModule pkgs {
          projectRootFile = "flake.nix";
          # nixfmt-rfc-style: the standard Nix formatter (RFC 166).
          programs.nixfmt.enable = true;
          settings.formatter = {
            prettier = {
              command = "${pkgs.prettier}/bin/prettier";
              options = [ "--write" ];
              includes = [ "*.md" ];
            };
            shfmt = {
              command = "${pkgs.shfmt}/bin/shfmt";
              options = [
                "-w"
                "-i"
                "2"
                "-ci"
              ];
              includes = [
                "*.sh"
                "*.bash"
              ];
            };
          };
        };
      in
      {
        formatter = treefmtEval.config.build.wrapper;

        # `nix flake check` / CI: unit tests for every deployed alert rule
        # (incl. the sloth-generated burn-rate rules) and a VM test of the
        # prometheus → alertmanager → webhook delivery pipeline.
        checks = pkgs.lib.optionalAttrs (system == "x86_64-linux") {
          prometheus-rules = import ./checks/prometheus-rules { inherit pkgs self; };
          monitoring-pipeline = import ./checks/monitoring-pipeline.nix { inherit pkgs self; };
          # Fail if any host exposes an exporter/service that nothing scrapes.
          monitoring-coverage = import ./checks/monitoring-coverage { inherit pkgs self; };
        };

        devShells.default =
          let
            hostNames = builtins.attrNames self.nixosConfigurations;
          in
          pkgs.mkShell {
            buildInputs = [
              treefmtEval.config.build.wrapper
              pkgs.unstable.prek
              pkgs.colmena
              pkgs.webrepl_cli

              (pkgs.writeShellScriptBin "ship" ''
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
      }
    )
    // (
      let
        mkRpiBootstrap = import ./lib/rpi-bootstrap.nix {
          inherit nixos-generators inputs overlays;
        };
        rpiPkgs = import nixpkgs-stable {
          system = "aarch64-linux";
          inherit overlays;
        };
        allowMissingModulesOverlay = _: super: {
          makeModulesClosure = x: super.makeModulesClosure (x // { allowMissing = true; });
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
            my.bootstrap = bootstrapSecrets // {
              enable = true;
              name = "bootstrap5";
            };
          }
        ];
      in
      {
        # Bootstrap SD image for Raspberry Pi 4 (nixpkgs sd-image-aarch64).
        packages.aarch64-linux.rpi4 = mkRpiBootstrap (
          bootstrapSecrets
          // {
            name = "bootstrap4";
            hardwareModule = ./common/rpi4-configuration.nix;
            extraOverlays = [ allowMissingModulesOverlay ];
            extraModules = [
              {
                boot.kernelPackages = rpiPkgs.lib.mkForce rpiPkgs.linuxPackages_rpi4;
              }
            ];
          }
        );

        # Bootstrap SD image for Raspberry Pi 5 (nixos-raspberrypi).
        # nixosSystemFull pulls the Pi-optimised pkgs overlay (ffmpeg,
        # kodi, libcamera, libpisp). For a headless server that overlay
        # is a no-op since nothing references those packages, so cost is
        # zero and future camera/kodi work gets the optimised variants
        # for free.
        packages.aarch64-linux.rpi5 =
          (inputs.nixos-raspberrypi.lib.nixosSystemFull {
            specialArgs = { inherit inputs; };
            modules = rpi5Modules;
          }).config.system.build.sdImage;
      }
    );
}
