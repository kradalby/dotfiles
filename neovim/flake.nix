{
  description = "kradalby's Neovim distribution";
  inputs =
    # let
    #   nvimPlugin = ghurl: let
    #     pluginName = builtins.elemAt (builtins.split "/" ghurl) 1;
    #   in {
    #     "name" = "vim:${pluginName}";
    #     "value" = {
    #       url = "github:${ghurl}";
    #       flake = false;
    #     };
    #   };
    #
    #   nvimPluginsDef = builtins.listToAttrs (builtins.map nvimPlugin [
    #     "nvim-dap"
    #     "nvim-dap-go"
    #     "nvim-dap-python"
    #     "rcarriga/nvim-dap-ui"
    #
    #     # Libraries/Shared stuff
    #     "plenary.nvim"
    #   ]);
    # in
    {
      flake-utils.url = "github:numtide/flake-utils";

      flake-compat = {
        url = "github:edolstra/flake-compat";
        flake = false;
      };

      nixpkgs.url = "github:nixos/nixpkgs/nixos-22.11";

      # "vim:" = {
      #   url = "github:";
      #   flake = false;
      # };

      "vim:nvim-ts-rainbow" = {
        url = "github:p00f/nvim-ts-rainbow";
        flake = false;
      };

      "vim:nvim-colorizer.lua" = {
        url = "github:norcalli/nvim-colorizer.lua";
        flake = false;
      };

      "vim:nvim-lspconfig" = {
        url = "github:neovim/nvim-lspconfig";
        flake = false;
      };

      "vim:lsp-status.nvim" = {
        url = "github:nvim-lua/lsp-status.nvim";
        flake = false;
      };

      "vim:neodev.nvim" = {
        url = "github:folke/neodev.nvim";
        flake = false;
      };

      "vim:null-ls.nvim" = {
        url = "github:jose-elias-alvarez/null-ls.nvim";
        flake = false;
      };

      "vim:schemastore.nvim" = {
        url = "github:b0o/schemastore.nvim";
        flake = false;
      };

      "vim:nvim-cmp" = {
        url = "github:hrsh7th/nvim-cmp";
        flake = false;
      };

      "vim:cmp-buffer" = {
        url = "github:hrsh7th/cmp-buffer";
        flake = false;
      };

      "vim:cmp-nvim-lsp" = {
        url = "github:hrsh7th/cmp-nvim-lsp";
        flake = false;
      };

      "vim:cmp-path" = {
        url = "github:hrsh7th/cmp-path";
        flake = false;
      };

      "vim:cmp-vsnip" = {
        url = "github:hrsh7th/cmp-vsnip";
        flake = false;
      };

      "vim:cmp-cmdline" = {
        url = "github:hrsh7th/cmp-cmdline";
        flake = false;
      };

      "vim:cmp-nvim-lsp-signature-help" = {
        url = "github:hrsh7th/cmp-nvim-lsp-signature-help";
        flake = false;
      };

      "vim:cmp-git" = {
        url = "github:petertriho/cmp-git";
        flake = false;
      };

      "vim:vim-vsnip" = {
        url = "github:hrsh7th/vim-vsnip";
        flake = false;
      };

      "vim:lspkind-nvim" = {
        url = "github:onsails/lspkind-nvim";
        flake = false;
      };

      "vim:nvim-autopairs" = {
        url = "github:windwp/nvim-autopairs";
        flake = false;
      };

      "vim:lspsaga.nvim" = {
        url = "github:glepnir/lspsaga.nvim";
        flake = false;
      };

      "vim:mini.nvim" = {
        url = "github:echasnovski/mini.nvim";
        flake = false;
      };

      "vim:vim-plist" = {
        url = "github:darfink/vim-plist";
        flake = false;
      };

      "vim:nvim-web-devicons" = {
        url = "github:kyazdani42/nvim-web-devicons";
        flake = false;
      };

      "vim:tokyonight.nvim" = {
        url = "github:folke/tokyonight.nvim";
        flake = false;
      };

      "vim:nvim-neoclip.lua" = {
        url = "github:AckslD/nvim-neoclip.lua";
        flake = false;
      };

      "vim:sqlite.lua" = {
        url = "github:tami5/sqlite.lua";
        flake = false;
      };

      "vim:Comment.nvim" = {
        url = "github:numToStr/Comment.nvim";
        flake = false;
      };

      "vim:gitsigns.nvim" = {
        url = "github:lewis6991/gitsigns.nvim";
        flake = false;
      };

      "vim:vim-polyglot" = {
        url = "github:sheerun/vim-polyglot";
        flake = false;
      };

      "vim:vim-cooklang" = {
        url = "github:luizribeiro/vim-cooklang";
        flake = false;
      };

      "vim:octo.nvim" = {
        url = "github:pwntester/octo.nvim";
        flake = false;
      };

      "vim:trouble.nvim" = {
        url = "github:folke/trouble.nvim";
        flake = false;
      };

      "vim:todo-comments.nvim" = {
        url = "github:folke/todo-comments.nvim";
        flake = false;
      };

      "vim:nvim-dap" = {
        url = "github:mfussenegger/nvim-dap";
        flake = false;
      };

      "vim:nvim-dap-ui" = {
        url = "github:rcarriga/nvim-dap-ui";
        flake = false;
      };

      "vim:nvim-dap-python" = {
        url = "github:mfussenegger/nvim-dap-python";
        flake = false;
      };

      "vim:nvim-dap-go" = {
        url = "github:leoluz/nvim-dap-go";
        flake = false;
      };

      "vim:nvim-dap-virtual-text" = {
        url = "github:theHamsta/nvim-dap-virtual-text";
        flake = false;
      };

      "vim:telescope-dap.nvim" = {
        url = "github:nvim-telescope/telescope-dap.nvim";
        flake = false;
      };

      "vim:plenary.nvim" = {
        url = "github:nvim-lua/plenary.nvim";
        flake = false;
      };

      "vim:telescope-ui-select.nvim" = {
        url = "github:nvim-telescope/telescope-ui-select.nvim";
        flake = false;
      };

      "vim:telescope.nvim" = {
        url = "github:nvim-telescope/telescope.nvim";
        flake = false;
      };

      "vim:rust-tools.nvim" = {
        url = "github:simrat39/rust-tools.nvim";
        flake = false;
      };

      # These require special treatment (ie, compilation), so we can't load them in bulk
      "telescope-fzf-native.nvim" = {
        url = "github:nvim-telescope/telescope-fzf-native.nvim";
        flake = false;
      };
    };

  outputs =
    { self
    , flake-utils
    , nixpkgs
    , ...
    } @ inputs:
    {
      overlay = final: prev:
        let
          pkgs = import nixpkgs {
            inherit (prev) system;
            # overlays = [neovim-nightly-overlay.overlay];
          };

          # Build Vim plugin flake inputs into a list of Nix packages
          vimPackages = with pkgs.lib;
            with strings;
            mapAttrsToList
              (n: v:
                pkgs.vimUtils.buildVimPluginFrom2Nix {
                  name = removePrefix "vim:" n;
                  src = v.outPath;
                  namePrefix = "";
                })
              (filterAttrs (n: v: hasPrefix "vim:" n) inputs);

          telescopeFzfNative = pkgs.vimUtils.buildVimPluginFrom2Nix {
            name = "telescope-fzf-native.nvim";
            src = inputs."telescope-fzf-native.nvim".outPath;
            namePrefix = "";
            buildPhase = ''
              make
            '';
          };

          neovim-nix-lua-conf = pkgs.writeText "nix.lua" ''
            vim.g.sqlite_clib_path = "${pkgs.sqlite.out}/lib/${
              if pkgs.stdenv.isDarwin
              then "libsqlite3.dylib"
              else "libsqlite3.so"
            }"
          '';

          # TODO: Only copy *.lua files, maybe with `nix-filter`
          # Make a derivation containing only Neovim Lua config
          neovim-kradalby-luaconfig = pkgs.stdenv.mkDerivation rec {
            name = "neovim-kradalby-luaconfig";
            src = pkgs.nix-gitignore.gitignoreSource [ ] ./.;
            phases = "installPhase";
            installPhase = ''
              mkdir -p $out/lua
              cp ${neovim-nix-lua-conf} $out/lua/nix.lua
              cp -r ${src}/init.lua $out/init.lua
              cp -r ${src}/lua/* $out/lua/.
            '';
          };
        in
        {
          # Wrap Neovim with custom plugins and config
          neovim-kradalby = pkgs.neovim.override {
            viAlias = true;
            vimAlias = true;
            withNodeJs = false;

            configure = {
              packages.kradalby = with pkgs.vimPlugins; {
                start =
                  [
                    (nvim-treesitter.withPlugins (_: pkgs.tree-sitter.allGrammars))
                    telescopeFzfNative
                  ]
                  ++ vimPackages;
              };

              customRC = ''
                set runtimepath^=${neovim-kradalby-luaconfig}
                luafile ${neovim-kradalby-luaconfig}/init.lua
              '';
            };
          };
        };
    }
    // flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ self.overlay ];
        };
      in
      rec {
        packages = with pkgs; {
          inherit neovim-kradalby;

          default = neovim-kradalby;
        };

        defaultPackage = packages.neovim-kradalby;
        apps.neovim-kradalby = flake-utils.lib.mkApp { drv = packages.neovim-kradalby; };
        defaultApp = apps.neovim-kradalby;

        overlays.default = self.overlay;
      }
    );
}
