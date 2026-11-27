{ inputs }:
let
  # A tack pin's source and version: tag pins carry their tag, branch pins the
  # short rev.
  pin =
    name:
    let
      m = inputs._meta.${name};
    in
    {
      src = inputs.${name};
      version =
        if m.tag or null != null then
          builtins.head (builtins.match "v?(.*)" m.tag)
        else
          builtins.substring 0 7 m.rev;
    };
in
final: prev: {
  # Built on plain nixpkgs-unstable, as the standalone flake was.
  neovim-kradalby =
    inputs.nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system}.callPackage ../neovim
      {
        plugins = builtins.mapAttrs (name: _: pin name) (
          prev.lib.filterAttrs (_: m: m.group or null == "nvim-plugins") inputs._meta
        );
      };

  # Releases track the newest Go release; take master's when it is ahead of
  # the fleet's.
  tailscale-tools = prev.callPackage ./tailscale-tools.nix (
    pin "tailscale-tools"
    // {
      buildGoModule = prev.buildGoModule.override {
        go =
          let
            masterGo = inputs.nixpkgs-master.legacyPackages.${prev.stdenv.hostPlatform.system}.go_latest;
          in
          if prev.lib.versionOlder prev.go.version masterGo.version then masterGo else prev.go;
      };
    }
  );

  setec = prev.callPackage ./setec.nix (pin "setec");

  squibble = prev.callPackage ./squibble.nix (pin "squibble");

  eb = prev.callPackage ./eb.nix (pin "eb");

  cook-cli = prev.callPackage ./cook.nix (pin "cook-cli");

  cook-mcp = prev.callPackage ./cook-mcp.nix (pin "cook-mcp");

  mcp-picnic = prev.callPackage ./mcp-picnic.nix (pin "mcp-picnic");

  authkey = prev.callPackage ./authkey { };

  rnb = prev.callPackage ./rnb { };

  rustic-wrapper = prev.callPackage ../rustic-wrapper { };

  p3-controller = prev.callPackage ../p3-controller { };

  ac-web = prev.callPackage ../ac-web { };

  oci-usage-exporter = prev.callPackage ../oci-usage-exporter { };

  github-star-feed = prev.callPackage ../github-star-feed { };

  energyd = prev.callPackage ../energyd { };

  dashboards = prev.callPackage ../dashboards { };

  pm-cli = prev.callPackage ./pm-cli.nix (pin "pm-cli");

  herald = prev.callPackage ./herald.nix (pin "herald");

  # home/fish.nix plugins; home-manager modules see pkgs, not inputs.
  fish-plugin-srcs = {
    nix-env = inputs.fish-nix-env;
    abbr-tips = inputs.fish-abbr-tips;
  };

  gotools = prev.callPackage ./gotools.nix ({ inherit (prev) gotools; } // pin "gotools");

  # Stable still has rich 14.x's aarch64 broken-pipe test failure; unstable's
  # rich 15.x no longer needs the workaround.
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (pyfinal: pyprev: {
      rich =
        if prev.stdenv.hostPlatform.isAarch64 && prev.lib.versionOlder pyprev.rich.version "15" then
          pyprev.rich.overridePythonAttrs (old: {
            disabledTests = (old.disabledTests or [ ]) ++ [ "test_brokenpipeerror" ];
          })
        else
          pyprev.rich;
    })
  ];

  # osxphotos = prev.callPackage ./osxphotos.nix {};
}
