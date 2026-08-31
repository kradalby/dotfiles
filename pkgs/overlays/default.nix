{ ... }:
let
in
final: prev: {
  tailscale-tools = prev.callPackage ./tailscale-tools.nix { };

  # Pinned to Go 1.26: setec vendors a go-json-experiment that predates the
  # encoding/json/v2 landing in 1.27, so the fleet toolchain fails it with
  # `undefined: json.SkipFunc`. Upstream setec is already at HEAD, so the
  # toolchain is the thing to pin, not the source. Drop once setec's vendored
  # go-json-experiment catches up. go_1_26 is 1.26.7, above setec's 1.26.6 floor.
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
