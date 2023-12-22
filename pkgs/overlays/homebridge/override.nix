{
  pkgs,
  system,
  plugins ? [],
}: let
  nodePackages = import ./default.nix {
    inherit pkgs system;
  };

  homebridgePackages =
    nodePackages;

  packageModulePath = package: "${package}/lib/node_modules/";
  nodeModulePaths = map packageModulePath (builtins.attrValues homebridgePackages);
  pluginPaths = map packageModulePath plugins;
  nodePath = builtins.concatStringsSep ":" (nodeModulePaths ++ pluginPaths);
in
  pkgs.stdenv.mkDerivation rec {
    version = "1.0.0";
    name = "homebridge-${version}";
    unpackPhase = "true";
    buildPhase = "true";
    installPhase = ''
      mkdir -p $out/bin
      cat > $out/bin/homebridge <<EOF
      #!/bin/sh
      NODE_PATH=${nodePath} exec ${homebridgePackages.homebridge}/bin/homebridge -U ~/ -I "$@"
      EOF
      chmod +x $out/bin/homebridge
    '';
  }
