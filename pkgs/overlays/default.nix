{ ... }:
let
in
final: prev: {
  tailscale-tools = prev.callPackage ./tailscale-tools.nix { };

  # setec vendors a go-json-experiment predating encoding/json/v2, so the fleet's
  # 1.27 toolchain fails it. Upstream is at HEAD; pin the toolchain, not the source.
  setec = prev.callPackage ./setec.nix { buildGoModule = prev.buildGo126Module; };

  squibble = prev.callPackage ./squibble.nix { };

  eb = prev.callPackage ./eb.nix { };

  cook-cli = prev.callPackage ./cook.nix { };

  webrepl_cli = prev.callPackage ./webrepl_cli.nix { };

  authkey = prev.callPackage ./authkey { };

  rnb = prev.callPackage ./rnb { };

  rustic-wrapper = prev.callPackage ../rustic-wrapper { };

  p3-controller = prev.callPackage ../p3-controller { };

  ac-web = prev.callPackage ../ac-web { };

  oci-usage-exporter = prev.callPackage ../oci-usage-exporter { };

  ghostty-tab = prev.callPackage ./ghostty-tab.nix { };

  pm-cli = prev.callPackage ./pm-cli.nix { };

  # osxphotos = prev.callPackage ./osxphotos.nix {};
}
