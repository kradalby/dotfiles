{ pkgs, self }:
let
  lib = pkgs.lib;
  dag = import (self.inputs.home-manager + "/modules/lib/dag.nix") { inherit lib; };
  configs = [
    self.homeConfigurations."ubuntu@kradalby-llm".config
    self.darwinConfigurations.krair.config.home-manager.users.kradalby
    self.darwinConfigurations.kratail2.config.home-manager.users.kradalby
  ];
  ordered =
    config:
    let
      names = map (entry: entry.name) (dag.topoSort config.home.activation).result;
      index =
        name:
        lib.lists.findFirstIndex (entry: entry == name) (throw "missing activation node ${name}") names;
    in
    index "linkGeneration" < index "mutableJson";
  base = {
    home.username = "fixture";
    home.homeDirectory = "/fixture";
    home.stateVersion = "26.05";
  };
  old = self.inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      base
      { home.file.".config/tool/config.json".text = ''{"old":true}''; }
    ];
  };
  new = self.inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      ../../home/mutable-json.nix
      base
      {
        my.mutableJson.fixture = {
          target = ".config/tool/config.json";
          value.canonical = true;
        };
      }
    ];
  };
  seed = pkgs.writeShellScript "seed-mutable-json" ''
    set -euo pipefail
    run() { "$@"; }
    ${new.config.home.activation.mutableJson.data}
  '';
  link = pkgs.writeShellScript "link-mutable-json" ''
    set -euo pipefail
    export VERBOSE_ARG=""
    ${new.config.lib.bash.initHomeManagerLib}
    ${new.config.home.activation.linkGeneration.data}
  '';
in
assert lib.all ordered configs;
pkgs.runCommand "mutable-json-test"
  {
    nativeBuildInputs = with pkgs; [
      bash
      coreutils
      findutils
      gettext
    ];
  }
  ''
    unset BASH_ENV ENV
    export HOME="$TMPDIR/fresh"
    mkdir -p "$HOME"
    ${seed}
    test -f "$HOME/.config/tool/config.json"
    test ! -L "$HOME/.config/tool/config.json"
    test -w "$HOME/.config/tool/config.json"
    test "$(stat -c %a "$HOME/.config/tool/config.json")" = 644

    export HOME="$TMPDIR/migration"
    export oldGenPath="$TMPDIR/old"
    export newGenPath="$TMPDIR/new"
    mkdir -p "$HOME/.config/tool" "$oldGenPath" "$newGenPath"
    ln -s ${old.config.home-files} "$oldGenPath/home-files"
    ln -s ${new.config.home-files} "$newGenPath/home-files"
    ln -s ${old.config.home-files}/.config/tool/config.json "$HOME/.config/tool/config.json"
    ${link}
    test ! -e "$HOME/.config/tool/config.json"
    ${seed}
    cmp "$HOME/.config/tool/config.json" "$HOME/.config/tool/config.json.nix"
    test ! -L "$HOME/.config/tool/config.json"
    test -w "$HOME/.config/tool/config.json"

    printf '%s\n' '{"deliberate":true}' > "$HOME/.config/tool/config.json"
    chmod 600 "$HOME/.config/tool/config.json"
    before="$(sha256sum "$HOME/.config/tool/config.json") $(stat -c %i:%a:%Y "$HOME/.config/tool/config.json")"
    ${link}
    ${seed}
    ${seed}
    test "$before" = "$(sha256sum "$HOME/.config/tool/config.json") $(stat -c %i:%a:%Y "$HOME/.config/tool/config.json")"
    touch "$out"
  ''
