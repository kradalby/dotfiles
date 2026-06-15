{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.my.mutableJson;
  jsonFor = name: value: (pkgs.formats.json {}).generate "${name}.json" value;

  # Per entry: a diff against the published nix reference, and a reset
  # that adopts the nix version (discarding live edits).
  aliasesFor = name: f: [
    (lib.nameValuePair "${name}-diff" "diff -u $HOME/${f.target}.nix $HOME/${f.target}")
    (lib.nameValuePair "${name}-reset" "cp $HOME/${f.target}.nix $HOME/${f.target}")
  ];
in {
  options.my.mutableJson = lib.mkOption {
    default = {};
    description = ''
      JSON config that nix defines but a client app mutates at runtime.
      home-manager can only symlink into the read-only store, which breaks
      apps that write their own config. For each entry this publishes the
      canonical content at <target>.nix (an ordinary store symlink the app
      never touches), seeds <target> with a writable copy if it does not
      already exist, and adds <name>-diff / <name>-reset helpers. An
      existing live file is never overwritten.
    '';
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        target = lib.mkOption {
          type = lib.types.str;
          description = "Path of the live file, relative to $HOME.";
        };
        value = lib.mkOption {
          type = lib.types.attrs;
          description = "Canonical JSON content.";
        };
      };
    });
  };

  config = lib.mkIf (cfg != {}) {
    # Publish the canonical content next to the live file.
    home.file =
      lib.mapAttrs'
      (name: f: lib.nameValuePair "${f.target}.nix" {source = jsonFor name f.value;})
      cfg;

    # Seed the live file from the store path if it is missing. Seeding from
    # the store path (not the .nix symlink) avoids depending on link order.
    home.activation.mutableJson = lib.hm.dag.entryAfter ["writeBoundary"] (
      lib.concatStringsSep "\n" (lib.mapAttrsToList (name: f: ''
        [ -e "$HOME/${f.target}" ] || run install -m644 "${jsonFor name f.value}" "$HOME/${f.target}"
      '')
      cfg)
    );

    programs.fish.shellAliases =
      lib.listToAttrs (lib.concatLists (lib.mapAttrsToList aliasesFor cfg));
  };
}
