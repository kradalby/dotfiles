{pkgs, ...}: let
  src = pkgs.fetchFromGitHub {
    owner = "umami-software";
    repo = "umami";
    rev = "v1.39.5";
    sha256 = "sha256-6YT35V/PiXe4Rym3xS8FKvwZghCZRyo/T/6cPxyavSs=";
  };

  umamiDeps = pkgs.yarn2nix-moretea.mkYarnPackage {
    name = "umami";
    inherit src;

    yarnPostBuild = ''
      export DATABASE_URL=postgresql://
      cd ${src}
      ${pkgs.yarn}/bin/yarn copy-db-files
      ${pkgs.yarn}/bin/yarn build-db-client
    '';
  };
in
  pkgs.stdenv.mkDerivation {
    name = "umami";
    inherit src;

    buildInputs = with pkgs; [
      umamiDeps

      openssl
      yarn
      # nodePackages.prisma
    ];

    postUnpack = ''
      export HOME="$TMP"
    '';

    patchPhase = ''
      ln -fs ${umamiDeps}/libexec/umami/node_modules .
    '';

    buildPhase = ''
      # ${pkgs.yarn}/bin/yarn build-db
      ${pkgs.yarn}/bin/yarn copy-db-files
      ${pkgs.yarn}/bin/yarn build-tracker
      ${pkgs.yarn}/bin/yarn build-geo
      ${pkgs.yarn}/bin/yarn build-app
    '';

    installPhase = ''
      mkdir -p $out

      cp -r next.config.js $out
      cp -r public $out/public
      cp -r package.json $out/package.json
      cp -r prisma $out/prisma
      cp -r scripts $out/scripts
      cp -r .next/standalone $out/
      cp -r .next/static $out/.next/static
    '';
  }
