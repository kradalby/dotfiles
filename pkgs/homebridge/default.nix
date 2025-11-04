{
  lib,
  stdenv,
  callPackage,
  # Optional: provide custom plugin list
  plugins ? [],
}:

let
  # Use upstream nixpkgs packages for homebridge core
  homebridge = callPackage ({pkgs}: pkgs.homebridge) {};
  homebridge-config-ui-x = callPackage ({pkgs}: pkgs.homebridge-config-ui-x) {};

  # Helper to get node_modules path for a package
  packageModulePath = package: "${package}/lib/node_modules/";

  # Combine homebridge core + config-ui + provided plugins into NODE_PATH
  nodePath = lib.concatStringsSep ":" (
    map packageModulePath ([homebridge homebridge-config-ui-x] ++ plugins)
  );
in
stdenv.mkDerivation {
  pname = "homebridge-with-plugins";
  version = homebridge.version;

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    mkdir -p $out/bin
    cat > $out/bin/homebridge <<EOF
#!/bin/sh
# Homebridge wrapper with custom plugins
# NODE_PATH includes homebridge core, config-ui, and plugins
NODE_PATH=${nodePath} exec ${homebridge}/bin/homebridge -U ~/ -I "\$@"
EOF
    chmod +x $out/bin/homebridge
  '';

  passthru = {
    inherit homebridge homebridge-config-ui-x plugins;

    # Helper function to create a homebridge with specific plugins
    withPlugins = newPlugins: callPackage ./. { plugins = newPlugins; };
  };

  meta = with lib; {
    description = "Homebridge with optional plugins";
    homepage = "https://github.com/homebridge/homebridge";
    license = licenses.asl20;
    mainProgram = "homebridge";
    platforms = platforms.linux ++ platforms.darwin;
  };
}
