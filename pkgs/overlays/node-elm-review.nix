{
  lib,
  config,
  dream2nix,
  ...
}: {
  imports = [
    dream2nix.modules.dream2nix.nodejs-package-lock
  ];

  nodejs-package-lock = {
    source = config.deps.fetchFromGitHub {
      owner = "jfmengels";
      repo = "node-elm-review";
      rev = "v2.11.0-beta.5";
      sha256 = "";
    };
  };

  deps = {nixpkgs, ...}: {
    inherit
      (nixpkgs)
      fetchFromGitHub
      stdenv
      ;
  };

  name = "elm-review";
  version = config.nodejs-package-lock.source.rev;

  mkDerivation = {
    src = config.nodejs-package-lock.source;
  };
}
