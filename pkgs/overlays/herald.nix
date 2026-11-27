{
  src,
  version,
  lib,
  stdenv,
  autoPatchelfHook,
}:
stdenv.mkDerivation {
  pname = "herald";
  inherit src version;

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ stdenv.cc.libc ];
  # The pin is the unpacked release tarball.
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    install -Dm755 "$src/herald" "$out/bin/herald"
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
