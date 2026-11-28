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
final: prev:
let
  # Our own Go packages build with the fleet Go; nixpkgs' keep the channel's.
  callGo =
    path: args:
    prev.lib.callPackageWith (
      final
      // {
        go = final.fleetGo;
        buildGoModule = final.buildFleetGoModule;
      }
    ) path args;
  # Dev tools must match the compiler they work on, so rebuild nixpkgs' with
  # the fleet Go. Only the Go args each package takes are replaced; a builder
  # pinned to an older major (lint support lag) stays.
  withFleetGo =
    pkg:
    let
      major = builtins.replaceStrings [ "." ] [ "" ] (prev.lib.versions.majorMinor final.fleetGo.version);
    in
    pkg.override (
      args:
      builtins.intersectAttrs args {
        go = final.fleetGo;
        buildGoModule = final.buildFleetGoModule;
        buildGoLatestModule = final.buildFleetGoModule;
        "buildGo${major}Module" = final.buildFleetGoModule;
      }
    );
in
{
  # Built on plain nixpkgs-unstable, as the standalone flake was.
  neovim-kradalby =
    inputs.nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system}.callPackage ../neovim
      {
        plugins = builtins.mapAttrs (name: _: pin name) (
          prev.lib.filterAttrs (_: m: m.group or null == "nvim-plugins") inputs._meta
        );
      };

  tailscale-tools = callGo ./tailscale-tools.nix (pin "tailscale-tools");

  setec = callGo ./setec.nix (pin "setec");

  squibble = callGo ./squibble.nix (pin "squibble");

  eb = prev.callPackage ./eb.nix (pin "eb");

  cook-cli = prev.callPackage ./cook.nix (pin "cook-cli");

  cook-mcp = prev.callPackage ./cook-mcp.nix (pin "cook-mcp");

  mcp-picnic = prev.callPackage ./mcp-picnic.nix (pin "mcp-picnic");

  authkey = callGo ./authkey { };

  rnb = callGo ./rnb { };

  rustic-wrapper = callGo ../rustic-wrapper { };

  p3-controller = callGo ../p3-controller { };

  ac-web = callGo ../ac-web { };

  oci-usage-exporter = callGo ../oci-usage-exporter { };

  github-star-feed = callGo ../github-star-feed { };

  energyd = callGo ../energyd { };

  dashboards = callGo ../dashboards { };

  pm-cli = callGo ./pm-cli.nix (pin "pm-cli");

  herald = prev.callPackage ./herald.nix (pin "herald");

  # home/fish.nix plugins; home-manager modules see pkgs, not inputs.
  fish-plugin-srcs = {
    nix-env = inputs.fish-nix-env;
    abbr-tips = inputs.fish-abbr-tips;
  };

  gotools = prev.callPackage ./gotools.nix ({ gotools = withFleetGo prev.gotools; } // pin "gotools");
  gopls = withFleetGo prev.gopls;
  delve = withFleetGo prev.delve;
  golangci-lint = withFleetGo prev.golangci-lint;
  go-tools = withFleetGo prev.go-tools;
  gofumpt = withFleetGo prev.gofumpt;
  golines = withFleetGo prev.golines;
  gotestsum = withFleetGo prev.gotestsum;

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
