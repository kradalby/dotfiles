{pkgs, ...}: let
  inherit (pkgs) fetchurl;
  inherit (pkgs.stdenv) mkDerivation;
in
  mkDerivation rec {
    pname = "cook-cli";
    version = "0.1.6";
    # cldrVersion = "v0.1.6";
    dontBuild = true;
    src = fetchurl {
      url = "https://github.com/cooklang/CookCLI/releases/download/v${version}/CookCLI_${version}_darwin_amd64_arm64.zip";
      sha256 = "sha256-vK0dzRQe7negIuo5gbOGaqI3X/7Tf2EQzkG7o9S9CPA=";
    };
    unpackPhase = "${pkgs.unzip}/bin/unzip $src";
    installPhase = "install -m755 -D cook $out/bin/cook";
  }
