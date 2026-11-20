# nh, with the deploy gate in front of it. symlinkJoin with the gate first so
# its bin/nh wins while nh's man pages and shell completions survive.
{ pkgs, ... }:
let
  # unstable: 4.5 is the first nh with `os dry-activate`.
  nh = pkgs.unstable.nh;
  gate = pkgs.writeShellApplication {
    name = "nh";
    runtimeInputs = [ (import ./git-ready.nix { inherit pkgs; }) ];
    text = ''
      NH=${nh}/bin/nh
    ''
    + builtins.readFile ./nh-gate.sh;
  };
in
pkgs.symlinkJoin {
  name = "nh-gated";
  paths = [
    gate
    nh
  ];
}
