{ ... }:
let
in
final: prev: {
  golines = prev.callPackage ./golines.nix {
    # buildGoModule = prev.buildGo117Module;
  };

  # headscale = prev.callPackage ./headscale.nix {
  #   buildGoModule = prev.unstable.buildGo119Module;
  # };

  tailscale-nginx-auth = prev.callPackage ./tailscale-nginx-auth.nix {
    buildGoModule = prev.unstable.buildGo119Module;
  };

  act = prev.callPackage ./act.nix {
    buildGoModule = prev.buildGo118Module;
  };

  imapchive = prev.callPackage ./imapchive.nix {
    buildGoModule = prev.buildGo118Module;
  };

  junos_exporter = prev.callPackage ./junos_exporter.nix {
    buildGoModule = prev.buildGo118Module;
  };

  homebridge = prev.callPackage ./homebridge/override.nix { };

  homebridgePlugins = prev.callPackage ./homebridge-plugins { };

  rustdesk-server = prev.callPackage ./rustdesk-server.nix { };

  eb = prev.callPackage ./eb.nix { };

  cook-cli = prev.callPackage ./cook.nix { };

  umami = prev.callPackage ./umami.nix { };

  gitutil = prev.callPackage ./gitutil.nix { };

  # osxphotos = prev.callPackage ./osxphotos.nix {};

  miniupnpd-nft =
    let
      miniupnpdVersion = "2.2.3";
      miniupnpdSrc = builtins.fetchurl {
        url = "http://miniupnp.free.fr/files/download.php?file=miniupnpd-${miniupnpdVersion}.tar.gz";
        sha256 = "sha256:07080abrp0c22zmfmfb9qi4v2qfbv8zcw3gg4j4dm8r555d2s084";
        name = "miniupnpd-${miniupnpdVersion}.tar.gz";
      };
      scriptBinEnv = with prev; lib.makeBinPath [ which iproute2 nftables gnused coreutils gawk ];
    in
    prev.miniupnpd.overrideAttrs (finalAttrs: previousAttrs: {
      version = miniupnpdVersion;
      src = miniupnpdSrc;

      buildInputs =
        previousAttrs.buildInputs
        ++ [
          prev.git
          prev.libmnl
          prev.libnftnl
        ];

      makefile = "Makefile.linux_nft";

      postFixup = ''
        for script in $out/etc/miniupnpd/nft_{init,removeall}.sh
        do
          wrapProgram $script --set PATH '${scriptBinEnv}:$PATH'
        done
      '';
    });
  miniupnpd-ipt =
    let
      miniupnpdVersion = "2.3.1";
      miniupnpdSrc = builtins.fetchurl {
        url = "http://miniupnp.free.fr/files/download.php?file=miniupnpd-${miniupnpdVersion}.tar.gz";
        sha256 = "sha256:1ypgsfzi2h2glrc0bn79wfs7zpb2vhkkl0qy3sr8rvdv73qpm7b4";
        name = "miniupnpd-${miniupnpdVersion}.tar.gz";
      };
    in
    prev.miniupnpd.overrideAttrs (finalAttrs: previousAttrs: {
      version = miniupnpdVersion;
      src = miniupnpdSrc;
    });
}
