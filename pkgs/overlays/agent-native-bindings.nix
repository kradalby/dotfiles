final: prev:
let
  # Restore blank context lines stripped by the mandatory whitespace hook.
  codexPatch = builtins.path {
    name = "codex-native-selection.patch";
    path = builtins.toFile "codex-native-selection.patch" (
      builtins.replaceStrings [ "\n\n" ] [ "\n \n" ] (
        builtins.readFile ../patches/codex-native-selection.patch
      )
    );
  };
in
{
  herdr = prev.herdr.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ../patches/herdr-native-selection.patch ];
  });

  master = prev.master // {
    codex = prev.master.codex.overrideAttrs (old: {
      passthru = (old.passthru or { }) // {
        tests = ((old.passthru or { }).tests or { }) // {
          frontend-thread-selection = import ../../checks/ac-native-codex { pkgs = final; };
        };
      };
      # nixpkgs patches inside codex-rs; the native patch uses repository paths.
      postPatch = (old.postPatch or "") + ''
        patch -p2 --batch < ${codexPatch}
      '';
    });
  };
}
