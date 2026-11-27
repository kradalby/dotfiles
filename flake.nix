{
  description = "kradalby's system config";

  # No flake-level nixConfig: it only applies with accept-flake-config, which
  # we keep off (see common/nix.nix). Caches belong in nix.settings on the
  # hosts that need them.

  # Inputs are tack pins (.tack/pins.toml); `tack update` moves them.
  outputs =
    { self, ... }@args:
    let
      inputs = (import ./.tack) { overrides = args.tackOverrides or { }; } // {
        inherit self;
      };
      inherit (inputs)
        nixpkgs-stable
        darwin
        home-manager
        flake-utils
        ;
      # Single Go for the whole fleet: `go_latest` from nixpkgs-unstable, the
      # only channel whose default Go tracks the newest release — stable holds
      # its `go_latest` back a major, below what headscale, tsnixcache and hugin
      # require in go.mod. Bump by moving nixpkgs-unstable.
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
        # libcap builds only its captree tool with Go, yet sits under bubblewrap
        # and pulseaudio (codex, ffmpeg, ...). Our Go would rebuild all of them,
        # so keep the channel's and stay on Hydra's cache.
        libcap = (prev.libcap.override { inherit (prev) go; }).overrideAttrs {
          disallowedReferences = [ prev.go ];
        };
      };

      # Fallout from building all of nixpkgs' Go with our toolchain rather than
      # the one each package pinned. Must sit after goOverlay so `prev` is
      # already the fleet toolchain.
      goFixupsOverlay = _final: prev: {
        # golink's own flake pins an older buildGoNNNModule and imports nixpkgs
        # without overlays, so goOverlay cannot reach it. Rebuild it here to keep
        # it on the fleet toolchain.
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

        # Stable's 0.5.11 can drop WAL pages on replication and its checkpoint
        # test is flaky; both are fixed in 0.5.15. Drop once stable ships it.
        litestream = prev.unstable.litestream;
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
        # TODO: remove with the nixpkgs-stable-small input.
        stable-small = import inputs.nixpkgs-stable-small {
          system = final.stdenv.hostPlatform.system;
        };
      };

      overlays = with inputs; [
        overlay-pkgs
        goOverlay
        headscale.overlays.default
        golink.overlays.default
        krapage.overlays.default
        golinkdiff.overlays.default
        hvor.overlays.default
        tasmota-exporter.overlays.default
        homewizard-p1-exporter.overlays.default
        ghdl.overlays.default
        asparges.overlays.default
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
            # Named apart from nixpkgs' rex, an unrelated automation tool.
            rex-cli = inputs.rex.packages."${system}".rex;
            # The stub `rex skill setup` writes, so `rex skill status` reads current.
            # It asks the installed rex for the guide, which tracks that version.
            rex-skill = final.runCommand "rex-skill" { } ''
              export HOME=$TMPDIR REX_AUTOSTART=0
              ${final.rex-cli}/bin/rex skill setup --agent claude >/dev/null
              install -Dm644 $HOME/.claude/skills/rex/SKILL.md $out/SKILL.md
            '';
            ai-plugins = import ./home/ai-plugins.nix {
              inherit inputs;
              pkgs = final;
            };
            claude-plugins = final.ai-plugins.claude;
            nefit-homekit = inputs.nefit-homekit.packages."${system}".default;
            tasmota-homekit = inputs.tasmota-homekit.packages."${system}".default;
            z2m-homekit = inputs.z2m-homekit.packages."${system}".default;
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
      nixosModules.sqlite-backup = ./modules/sqlite-backup;
      nixosModules.sqlite-backup-monitoring = ./modules/sqlite-backup/monitoring.nix;

      nixosConfigurations =
        let
          hosts = {
            "core.oracldn" = box.nixosBox {
              arch = "aarch64-linux";
              name = "core.oracldn";
              modules = with inputs; [
                headscale.nixosModules.default
                golink.nixosModules.default
                krapage.nixosModules.default
                hvor.nixosModules.default
                tasmota-exporter.nixosModules.default
                homewizard-p1-exporter.nixosModules.default
                ghdl.nixosModules.default
                asparges.nixosModules.default
              ];
            };

            "dev.oracfurt" = box.nixosBox {
              arch = "aarch64-linux";
              name = "dev.oracfurt";
              modules = with inputs; [
                tsidp.nixosModules.default
              ];
            };

            "home.ldn" = box.nixosBox {
              arch = "x86_64-linux";
              name = "home.ldn";
              modules = with inputs; [
                nefit-homekit.nixosModules.default
                tasmota-homekit.nixosModules.default
                z2m-homekit.nixosModules.default
              ];
            };

            # "rpi.vetle" = box.nixosBox {
            #   arch = "aarch64-linux";
            #   name = "home.ldn";
            # };

            "dev.ldn" = box.nixosBox {
              arch = "x86_64-linux";
              homeBase = home-manager;
              name = "dev.ldn";
              # Sole builder for the fleet.
              buildOnTarget = true;
            };

            rpisc = box.nixosBox {
              arch = "aarch64-linux";
              name = "rpisc";
            };

            "rpi5.ldn" = box.nixosBox {
              arch = "aarch64-linux";
              # AI tools + userland (home/ai.nix) come with home-manager, same
              # as the other workstation-class hosts. The SD image stays a bare
              # bootstrap; everything above that is deployed here.
              homeBase = home-manager;
              name = "rpi5.ldn";
              # First deploy, before it joins tailscale:
              #   nh os switch . -H rpi5.ldn --target-host root@10.65.0.196
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
            };

            "ts1p.ldn" = box.nixosBox {
              arch = "x86_64-linux";
              name = "ts1p.ldn";
              modules = with inputs; [
                ts1p.nixosModules.default
              ];
            };

            # protonmail-bridge (svc:proton-bridge) + the mail-triage agents.
            "proton.ldn" = box.nixosBox {
              arch = "x86_64-linux";
              homeBase = home-manager;
              name = "proton.ldn";
            };

            # Remote backup / syncthing mirror at bassan (Sebastian's house);
            # the old lenovo.ldn dummy box repurposed. Bare-metal, ZFS data pool.
            "storage.bassan" = box.nixosBox {
              arch = "x86_64-linux";
              name = "storage.bassan";
            };

            "core.tjoda" = box.nixosBox {
              arch = "x86_64-linux";
              name = "core.tjoda";
              modules = with inputs; [
                hugin.nixosModules.default
              ];
            };

            # gigabuilder: bare-metal Incus VM host + tsnixcache cache.
            "gigabuilder" = box.nixosBox {
              arch = "x86_64-linux";
              name = "gigabuilder";
              # No upstream builder to offload to, so build on the target (32 cores).
              buildOnTarget = true;
              # Bootstrap by IP: --target-host root@194.32.107.146
              modules = with inputs; [
                tsnixcache.nixosModules.tsnixcache
              ];
            };

            # garnix CI: Incus VM on gigabuilder; the host is its remote nix builder.
            "garnix" = box.nixosBox {
              arch = "x86_64-linux";
              name = "garnix";
              modules = with inputs; [
                garnixlogs.nixosModules.default
              ];
              # Bootstrap by IP: --target-host root@10.68.10.10
            };
          };
        in
        # garnix's attribute matcher is dot-delimited, so it can't build
        # nixosConfigurations whose names contain '.'. Duplicate each host
        # under a dot-free key (dev.ldn -> dev-ldn) so garnix builds them.
        # The dupes also match tailnet names, so `nh os switch --target-host
        # root@dev-ldn` picks its config without -H. Drop once garnix handles
        # dotted/quoted names (see home/fish.nix TODO).
        hosts
        // builtins.listToAttrs (
          map (n: {
            name = builtins.replaceStrings [ "." ] [ "-" ] n;
            value = hosts.${n};
          }) (builtins.attrNames hosts)
        );

      # nh darwin switch . -H <host>
      darwinConfigurations =
        let
          kratail2Machine = {
            arch = "aarch64-darwin";
            username = "kradalby";
            hostname = "kratail2";
            homeDir = /Users/kradalby;
          };
          kratail2Modules = [ ];

          krairMachine = {
            arch = "aarch64-darwin";
            username = "kradalby";
            hostname = "krair";
            homeDir = /Users/kradalby;
          };
          rosetta = inputs.nix-rosetta-builder.darwinModules.default;
        in
        {
          kratail2 = box.macBox kratail2Machine darwin home-manager (kratail2Modules ++ [ rosetta ]);
          krair = box.macBox krairMachine darwin home-manager [ rosetta ];
        };

      homeConfigurations = {
        "ubuntu@kradalby-llm" = home-manager.lib.homeManagerConfiguration {
          pkgs = self.nixosConfigurations."dev.ldn".pkgs;
          modules = [
            inputs.nix-index-database.homeModules.nix-index
            (import ./home/rex-personal.nix { inherit inputs; })
            ./machines/kradalby-llm
          ];
          extraSpecialArgs = {
            inherit inputs;
          };
        };
      };
    }
    // flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-darwin" ] (
      system:
      let
        pkgs = import nixpkgs-stable { inherit overlays system; };

        # Single formatter entrypoint (`nix fmt` / the treefmt devShell binary).
        # prettier + shfmt are custom formatters pinned to the exact args the old
        # per-tool hooks used (prettier: markdown only; shfmt: -i 2 -ci), so
        # switching to treefmt reformats nothing.
        treefmtEval = inputs.treefmt-nix.lib.evalModule pkgs {
          projectRootFile = "flake.nix";
          # nixfmt: the standard Nix formatter (RFC 166).
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
          ai-plugins = import ./checks/ai-plugins { inherit pkgs; };
          claude-plugins = import ./checks/claude-plugins { inherit pkgs; };
          codex-session-env = import ./checks/codex-session-env { inherit pkgs; };
          mcp-servers = import ./checks/mcp-servers { inherit pkgs; };
          claude-mcp = import ./checks/claude-mcp { inherit pkgs self inputs; };
          claude-path = import ./checks/claude-path { inherit pkgs inputs; };
          mutable-json = import ./checks/mutable-json { inherit pkgs self inputs; };
          syncthing-init = import ./checks/syncthing-init { inherit pkgs inputs; };
          tmp-cleanup = import ./checks/tmp-cleanup { inherit pkgs; };
          wt = import ./checks/wt { inherit pkgs; };
          disk-cleanup = import ./checks/disk-cleanup { inherit pkgs; };
          nix-dev-env = import ./checks/nix-dev-env { inherit pkgs; };
          ac = import ./checks/ac { inherit pkgs; };
          bootstrap-images = import ./checks/bootstrap-images {
            pkgs = nixpkgs-stable.legacyPackages.${system};
            inherit inputs;
          };
          backups = import ./checks/backups { inherit pkgs self; };
          sqlite-backup = import ./modules/sqlite-backup/tests.nix { inherit pkgs; };
          sqlite-backup-ordering = import ./modules/sqlite-backup/ordering-test.nix { inherit pkgs; };
          # treefmt in check mode: fails when any file is unformatted, making
          # `nix fmt` enforceable in CI (git.md's claim, now true).
          formatting = treefmtEval.config.build.check self;
          opencode-aperture-models = import ./checks/opencode-aperture-models.nix { inherit pkgs; };
          rex-access = import ./checks/rex.nix { inherit pkgs self; };
          prometheus-rules = import ./checks/prometheus-rules { inherit pkgs self; };
          monitoring-pipeline = import ./checks/monitoring-pipeline.nix { inherit pkgs self; };
          umami = import ./checks/umami.nix { inherit pkgs self; };
          # Fail if any host exposes an exporter/service that nothing scrapes.
          monitoring-coverage = import ./checks/monitoring-coverage { inherit pkgs self; };
          inference = import ./checks/inference.nix { inherit pkgs self inputs; };
          # core.tjoda's NIC recovery ladder: it only runs unattended, so its
          # thresholds are exercised here rather than discovered during an outage.
          link-watchdog = import ./checks/link-watchdog { inherit pkgs self; };
          # In-repo Go packages: buildGoModule runs each module's tests in its
          # checkPhase, so exposing the builds as checks puts `go test` in CI.
          go-ac-web = pkgs.ac-web;
          go-p3-controller = pkgs.p3-controller;
          owntone-restart = pkgs.p3-controller.tests.owntone-restart;
          go-oci-usage-exporter = pkgs.oci-usage-exporter;
          go-github-star-feed = pkgs.github-star-feed;
          go-energyd = pkgs.energyd;
          go-dashboards = pkgs.dashboards;
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

        # nh here is wrapped with the deploy gate (git-ready): `os|darwin|home
        # switch|boot|test` refuse unless the repo is on main, clean, in sync
        # with origin and fully pushed. It is deliberately not an overlay --
        # that would gate nh for every consumer of this flake -- and it sits
        # ahead of the home-packages nh, so plain `nh` in this repo is gated.
        devShells.default = pkgs.mkShell {
          buildInputs = [
            treefmtEval.config.build.wrapper
            pkgs.unstable.prek
            (import ./pkgs/scripts/nh-gate.nix { inherit pkgs; })
            (import ./pkgs/scripts/git-ready.nix { inherit pkgs; })
            pkgs.webrepl_cli
          ];
        };

        # Warm tsnixcache with the arm hosts' closures (see pkgs/cache-arm.nix).
        apps.cache-arm = import ./pkgs/cache-arm.nix { inherit pkgs inputs system; };
      }
    )
    // {
      packages = import ./images { inherit inputs; };
    };
}
