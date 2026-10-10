{ ... }:
let
in
final: prev: {
  tailscale-tools = prev.callPackage ./tailscale-tools.nix { };

  setec = prev.callPackage ./setec.nix { };

  squibble = prev.callPackage ./squibble.nix { };

  eb = prev.callPackage ./eb.nix { };

  cook-cli = prev.callPackage ./cook.nix { };

  mcp-picnic = prev.callPackage ./mcp-picnic.nix { };

  webrepl_cli = prev.callPackage ./webrepl_cli.nix { };

  authkey = prev.callPackage ./authkey { };

  rnb = prev.callPackage ./rnb { };

  rustic-wrapper = prev.callPackage ../rustic-wrapper { };

  p3-controller = prev.callPackage ../p3-controller { };

  ac-web = prev.callPackage ../ac-web { };

  oci-usage-exporter = prev.callPackage ../oci-usage-exporter { };

  ghostty-tab = prev.callPackage ./ghostty-tab.nix { };

  pm-cli = prev.callPackage ./pm-cli.nix { };

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
