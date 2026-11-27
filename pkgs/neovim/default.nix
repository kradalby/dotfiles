# kradalby's Neovim: init.lua and lua/ beside this file, plugins from
# vimPlugins plus the `nvim-plugins` tack group (`plugins`: pname -> pin).
{
  lib,
  stdenv,
  neovim,
  vimPlugins,
  vimUtils,
  tree-sitter,
  sqlite,
  writeText,
  plugins,
}:
let
  pinnedPlugins = lib.mapAttrsToList (
    pname: pin:
    vimUtils.buildVimPlugin {
      inherit pname;
      inherit (pin) src version;
      doCheck = false;
    }
  ) plugins;

  nixLua = writeText "nix.lua" ''
    vim.g.sqlite_clib_path = "${sqlite.out}/lib/${
      if stdenv.hostPlatform.isDarwin then "libsqlite3.dylib" else "libsqlite3.so"
    }"
  '';

  luaconfig = stdenv.mkDerivation {
    name = "neovim-kradalby-luaconfig";
    src = lib.fileset.toSource {
      root = ./.;
      fileset = lib.fileset.unions [
        ./init.lua
        ./lua
      ];
    };
    phases = "installPhase";
    installPhase = ''
      mkdir -p $out/lua
      cp ${nixLua} $out/lua/nix.lua
      cp $src/init.lua $out/init.lua
      cp -r $src/lua/* $out/lua/.
    '';
  };
in
neovim.override {
  viAlias = true;
  vimAlias = true;
  withNodeJs = false;

  configure = {
    packages.kradalby.start =
      (with vimPlugins; [
        # All grammars but tlaplus: https://github.com/NixOS/nixpkgs/issues/341442
        (nvim-treesitter.withPlugins (
          _: builtins.filter (g: !(lib.hasInfix "tlaplus" (lib.getName g))) tree-sitter.allGrammars
        ))

        # Completion
        blink-cmp

        # LSP
        SchemaStore-nvim

        # Formatting & Linting
        conform-nvim
        nvim-lint

        # Telescope
        telescope-nvim
        telescope-fzf-native-nvim
        plenary-nvim

        # UI
        tokyonight-nvim
        nvim-web-devicons
        mini-nvim

        # Git
        gitsigns-nvim

        # Editor
        todo-comments-nvim
        nvim-neoclip-lua
        sqlite-lua
      ])
      ++ pinnedPlugins;

    customRC = ''
      set runtimepath^=${luaconfig}
      luafile ${luaconfig}/init.lua
    '';
  };
}
