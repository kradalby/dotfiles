{ pkgs, ... }:
pkgs.symlinkJoin {
  name = "wt";
  paths = [
    (pkgs.writeShellApplication {
      name = "wt";

      runtimeInputs = with pkgs; [
        coreutils
        direnv
        gawk
        gh
        git
      ];

      text = builtins.readFile ./wt.sh;
    })
    (pkgs.writeTextDir "share/fish/vendor_functions.d/wt.fish" (builtins.readFile ./wt.fish))
  ];
}
