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
  # `--sudo` resolves sudo from PATH, and the sudo in `environment.systemPackages`
  # is a plain store binary — only the /run/wrappers copy carries the setuid bit.
  # A devShell that lands sw/bin first makes activation die on "must be owned by
  # uid 0"; pin the wrappers dir ahead so the lookup cannot go wrong.
  postBuild = ''
    wrapProgram $out/bin/colmena \
      --prefix PATH : /run/wrappers/bin \
      --run '${gate}/bin/colmena-gate "$@" || exit 1'
  '';
}
