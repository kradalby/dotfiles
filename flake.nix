{
  description = "kradalby's system config";

  # No flake-level nixConfig: it only applies with accept-flake-config, which
  # we keep off (see common/nix.nix). Caches belong in nix.settings on the
  # hosts that need them.

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
      # Follows unstable: its go.mod needs go >= 1.27.0.
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # Self-hosted garnix CI (our fork's integration branch). Update independently
    # with `nix flake update garnix-ci`. Do NOT `follows` nixpkgs: garnix pins
    # nixpkgs-25.11-small + its own nixpkgsUnstable + libkrun for krun; overriding
    # them risks breaking the action-runner.
    garnix-ci.url = "github:kradalby/garnix/integration";

    headscale = {
      url = "github:juanfont/headscale/main";
      inputs."flake-utils".follows = "flake-utils";
      # Follows unstable: headscale go.mod now needs go >= 1.27.0, and only
      # unstable ships a final 1.27 (stable has 1.26.6 and a 1.27 rc).
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    golink = {
      # Follows unstable for the fleet-wide go_latest (1.27); its go.mod floor
      # of 1.26.6 is satisfied there too.
      url = "github:tailscale/golink";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      inputs.systems.follows = "flake-utils/systems";
    };

    hugin = {
      url = "github:kradalby/hugin";
      # Pinned, not following nixpkgs-unstable: unstable moved elm 0.19.1 ->
      # 0.19.2, and hugin's fetchElmDeps seeds ELM_HOME/0.19.1, so the 0.19.2
      # compiler finds an empty cache and reaches for the network the sandbox
      # denies. This rev is the last with elm 0.19.1; it still carries
      # go_latest 1.27.0. Drop the pin once hugin regenerates elm-srcs.nix.
      inputs.nixpkgs.url = "github:NixOS/nixpkgs/174eb786fb68e3a13e4e535a3deea479a0c07a6a";
      inputs."flake-utils".follows = "flake-utils";
    };

    # setec-compatible secrets server, pinned to the `initial` branch. Follows
    # nixpkgs-unstable so its go build tracks our toolchain.
    ts1p = {
      url = "github:kradalby/ts1p/initial";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    tsidp = {
      url = "github:tailscale/tsidp";
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

    munin.url = "github:kradalby/munin";

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

    hermes-agent = {
      url = "github:NousResearch/hermes-agent";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      inputs.home-manager.follows = "home-manager";
    };

    # Agent multiplexer (tmux replacement for `ac`). Do NOT `follows` its
    # rust-overlay — the package is built against the toolchain herdr pins.
    herdr = {
      url = "github:herdrdev/herdr/v0.8.2";
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
      # Single Go for the whole fleet: go_latest from nixpkgs-unstable, which
      # is 1.27. Stable cannot serve this — its newest is 1.26.6 and its
      # go_1_27 is an rc, and an rc sorts below the `go 1.27.0` that headscale,
      # tsnixcache and hugin now require. Bump by moving nixpkgs-unstable.
      goLatest =
        system:
        (import inputs.nixpkgs-unstable {
          inherit system;
          config.allowUnfree = true;
        }).go_latest;

      goOverlay = _final: prev: {
        go = goLatest prev.stdenv.hostPlatform.system;
        buildGoModule = prev.buildGoModule.override {
          go = goLatest prev.stdenv.hostPlatform.system;
        };
      };

      # Fallout from building all of nixpkgs' Go with our toolchain rather than
      # the one each package pinned. Must sit after goOverlay so `prev` is
      # already the 1.27 build.
      goFixupsOverlay = _final: prev: {
        # golink hardcodes pkgs.buildGo126Module, and unstable's go_1_26 is
        # 1.26.5 — below golink's own go.mod floor of 1.26.6, so its flake
        # package cannot build here at all. Rebuild it on the fleet toolchain.
        golink = prev.buildGoModule {
          pname = "golink";
          version = inputs.golink.shortRev or "dev";
          src = inputs.golink;
          vendorHash = prev.lib.fileContents "${inputs.golink}/go.mod.sri";
          ldflags =
            let
              tsVersion = builtins.head (
                builtins.match ".*tailscale.com v([0-9]+\\.[0-9]+\\.[0-9]+-?[a-zA-Z]?).*" (
                  builtins.readFile "${inputs.golink}/go.mod"
                )
              );
            in
            [
              "-w"
              "-s"
              "-X tailscale.com/version.longStamp=${tsVersion}"
              "-X tailscale.com/version.shortStamp=${tsVersion}"
            ];
        };

        # generate-database's parser tests panic under 1.27 (parse_test.go:40,
        # index out of range). They cover a build-time code generator, not the
        # daemon we run. Drop once upstream incus supports 1.27.
        incus = prev.incus.overrideAttrs { doCheck = false; };
        incus-lts = prev.incus-lts.overrideAttrs { doCheck = false; };
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
        # Adds `munin-gallery` (binary `munin`), x86_64-linux only.
        munin.overlays.default
        # After the input overlays: it replaces packages they define.
        goFixupsOverlay
        (import ./pkgs/overlays { })
        (
          final: prev:
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
            # The agent skill (teaches an agent to drive herdr) is bundled in the
            # binary and printed by `herdr --skill`, so it tracks the package
            # version — nothing to vendor or maintain.
            herdr-skill = final.runCommand "herdr-skill.md" { } "${final.herdr}/bin/herdr --skill > $out";
            nefit-homekit = inputs.nefit-homekit.packages."${system}".default;
            tasmota-homekit = inputs.tasmota-homekit.packages."${system}".default;
            z2m-homekit = inputs.z2m-homekit.packages."${system}".default;
            # Upstream Nix build requires bun >= 1.3.14; nixpkgs-unstable has 1.3.13.
            # Use prebuilt binaries until nixpkgs ships bun 1.3.14+.
            opencode =
              let
                version = "1.18.20";
                srcs = {
                  x86_64-linux = {
                    url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-linux-x64-baseline.tar.gz";
                    hash = "sha256-NUdE8uSUtBLl1FcH7eJUu5nxEmD4RNwmCW++1d8DL3w=";
                  };
                  aarch64-darwin = {
                    url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-darwin-arm64.zip";
                    hash = "sha256-tIPlR8AptPC6OB8NDFtCC+xIwkwrvsH7fyIlK66D2kY=";
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
        # Plain string, not mkIf: a dirty tree gets an explicit DIRTY marker in
        # system.configurationRevision instead of silently reporting null.
        rev = if self ? rev then self.rev else "DIRTY";
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

            # Remote backup / syncthing mirror at bassan (Sebastian's house);
            # the old lenovo.ldn dummy box repurposed. Bare-metal, ZFS data pool.
            "storage.bassan" = box.nixosBox {
              arch = "x86_64-linux";
              name = "storage.bassan";
              tags = [
                "x86"
                "bassan"
              ];
            };

            "core.tjoda" = box.nixosBox {
              arch = "x86_64-linux";
              name = "core.tjoda";
              tags = [
                "x86"
                "router"
                "tjoda"
              ];
              modules = with inputs; [
                hugin.nixosModules.default
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
      darwinConfigurations =
        let
          kratail2Machine = {
            arch = "aarch64-darwin";
            username = "kradalby";
            hostname = "kratail2";
            homeDir = /Users/kradalby;
          };
          kratail2Modules = [
            inputs.ssh-agent-mux.darwinModules.default
            inputs.tailscale.darwinModules.default
          ];

          krairMachine = {
            arch = "aarch64-darwin";
            username = "kradalby";
            hostname = "krair";
            homeDir = /Users/kradalby;
          };
          krairModules = [ inputs.ssh-agent-mux.darwinModules.default ];

          rosetta = inputs.nix-rosetta-builder.darwinModules.default;
        in
        {
          kratail2 = box.macBox kratail2Machine darwin home-manager (kratail2Modules ++ [ rosetta ]);
          krair = box.macBox krairMachine darwin home-manager (krairModules ++ [ rosetta ]);
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
          # Go: gofumpt fleet-wide per docs/conventions/nix.md.
          programs.gofumpt.enable = true;
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
          # treefmt in check mode: fails when any file is unformatted, making
          # `nix fmt` enforceable in CI (git.md's claim, now true).
          formatting = treefmtEval.config.build.check self;
          aperture-agent-config-sync =
            let
              packages = self.homeConfigurations."ubuntu@kradalby-llm".config.home.packages;
              sync = builtins.head (
                builtins.filter (package: package.name == "aperture-agent-config-sync") packages
              );
            in
            sync.tests;
          prometheus-rules = import ./checks/prometheus-rules { inherit pkgs self; };
          monitoring-pipeline = import ./checks/monitoring-pipeline.nix { inherit pkgs self; };
          # Fail if any host exposes an exporter/service that nothing scrapes.
          monitoring-coverage = import ./checks/monitoring-coverage { inherit pkgs self; };
          # In-repo Go packages: buildGoModule runs each module's tests in its
          # checkPhase, so exposing the builds as checks puts `go test` in CI.
          go-ac-web = pkgs.ac-web;
          go-p3-controller = pkgs.p3-controller;
          go-oci-usage-exporter = pkgs.oci-usage-exporter;
          go-authkey = pkgs.authkey;
          go-rnb = pkgs.rnb;
          go-rustic-wrapper = pkgs.rustic-wrapper;
          # secrets/ and secrets/secrets.nix must stay 1:1 — an orphan file is
          # unrotatable cruft, a missing file breaks decryption. ANY stray file
          # (renamed .age.bak, editor droppings) counts, not just *.age.
          secrets-sync =
            let
              allFiles = builtins.attrNames (builtins.readDir ./secrets);
              # secrets.nix is the rules file; .gitattributes marks .age binary.
              onDisk = pkgs.lib.filter (
                n:
                !(pkgs.lib.elem n [
                  "secrets.nix"
                  ".gitattributes"
                ])
              ) allFiles;
              declared = builtins.attrNames (import ./secrets/secrets.nix);
              orphans = pkgs.lib.subtractLists declared onDisk;
              missing = pkgs.lib.subtractLists onDisk declared;
            in
            pkgs.runCommand "secrets-sync" { } (
              if orphans == [ ] && missing == [ ] then
                "touch $out"
              else
                ''
                  echo 'secrets/*.age and secrets.nix out of sync:' >&2
                  ${pkgs.lib.concatMapStrings (f: "echo '  on disk but not declared: ${f}' >&2\n") orphans}
                  ${pkgs.lib.concatMapStrings (f: "echo '  declared but no file: ${f}' >&2\n") missing}
                  exit 1
                ''
            );
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [
            treefmtEval.config.build.wrapper
            pkgs.unstable.prek
            pkgs.colmena
            pkgs.webrepl_cli
          ];
        };

        # Warm tsnixcache with the arm hosts' closures (see pkgs/cache-arm.nix).
        apps.cache-arm = import ./pkgs/cache-arm.nix { inherit pkgs inputs system; };
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

        # Bootstrap secrets come from the environment, never from a tracked
        # file of a public repo. Build with:
        #   BOOTSTRAP_WIFI_PSK=... BOOTSTRAP_TS_AUTHKEY=... \
        #     nix build .#rpi5 --impure
        # bootstrap-common.nix only WARNS when a variable is unset (pure-eval
        # flake checks legitimately eval these images with no env), so watch
        # the build output: a missed warning means an image that joins neither
        # wifi nor the tailnet. Mint the key one-time (authkey kradalby) — it
        # still lands in the image's store, which a spent key makes acceptable.
        bootstrapSecrets = {
          kadPsk = builtins.getEnv "BOOTSTRAP_WIFI_PSK";
          tsAuthKey = builtins.getEnv "BOOTSTRAP_TS_AUTHKEY";
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
