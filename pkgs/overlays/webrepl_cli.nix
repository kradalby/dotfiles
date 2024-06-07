{
pkgs,
fetchFromGitHub,
}:
pkgs.stdenv.mkDerivation rec {
    pname = "webrepl";
    version = "1e09d9a1d90fe52aba11d1e659afbc95a50cf088";

    src = fetchFromGitHub rec {
      inherit pname version;
      name = pname;
      rev = version;
      owner = "micropython";
      repo = pname;
      sha256 = "sha256-fUewic89i1TeQWLH66Bbic37KIgwtgPDLsYH1xKpExY=";
    };

    buildInputs = [ pkgs.python3 ];

    installPhase = ''install -Dm755 webrepl_cli.py $out/bin/webrepl_cli'';
    # preFixup = ''
    #   makeWrapperArgs+=(--prefix PATH : ${args.lib.makeBinPath []})
    # '';
}
