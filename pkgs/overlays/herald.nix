{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:
let
  versions = import ../../metadata/versions.nix;
in
stdenv.mkDerivation rec {
  pname = "herald";
  version = versions.pkgs.overlays.herald;

  src = fetchurl {
    url = "https://github.com/herald-email/herald-mail-app/releases/download/v${version}/herald-v${version}-linux-amd64.tar.gz";
    hash = "sha256-CoEhO4WEa7lf7EA65O4/9pCT+b50bhO/sFm4KAtpSeM=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ stdenv.cc.libc ];
  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    install -Dm755 herald "$out/bin/herald"
    runHook postInstall
  '';

  meta = {
    description = "Terminal email client";
    homepage = "https://herald-mail.app";
    mainProgram = "herald";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
  };
}
