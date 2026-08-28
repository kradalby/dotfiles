# colmena, with the deploy gate wrapped around it. symlinkJoin rather than a
# hand-written replacement so colmena's man pages and shell completions survive.
{ pkgs, ... }:
let
  gate = pkgs.writeShellApplication {
    name = "colmena-gate";
    runtimeInputs = [ (import ./git-ready.nix { inherit pkgs; }) ];
    text = builtins.readFile ./colmena-gate.sh;
  };
in
pkgs.symlinkJoin {
  name = "colmena-gated";
  paths = [ pkgs.colmena ];
  nativeBuildInputs = [ pkgs.makeWrapper ];
  postBuild = ''
    wrapProgram $out/bin/colmena \
      --run '${gate}/bin/colmena-gate "$@" || exit 1'
  '';
}
