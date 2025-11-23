{
pkgs,
fetchFromGitHub,
}: let
  versions = import ../../metadata/versions.nix;
in
pkgs.stdenv.mkDerivation rec {
    pname = "webrepl";
    version = versions.pkgs.overlays.webreplCli;

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
