{
  pkgs,
  lib,
  ...
}: {
  programs.vscode = {
    # Only install vscode on Macs for now.
    enable = pkgs.stdenv.isDarwin;
    enableUpdateCheck = false;

    package = pkgs.unstable.vscode.overrideAttrs (attrs: {
      meta = attrs.meta // {license = lib.licenses.mit;};
    });

    mutableExtensionsDir = true;
    extensions = with pkgs.vscode-marketplace; [
      arrterian.nix-env-selector
      bradlc.vscode-tailwindcss
      eamodio.gitlens
      editorconfig.editorconfig
      esbenp.prettier-vscode
      github.vscode-github-actions
      github.vscode-pull-request-github
      golang.go
      hashicorp.terraform
      ms-azuretools.vscode-docker
      ms-python.python
      # oderwat.indent-rainbow
      redhat.ansible
      vscode-icons-team.vscode-icons
      vscodevim.vim
      jnoortheen.nix-ide
      tailscale.vscode-tailscale
      ms-vscode-remote.remote-ssh
      ms-vsliveshare.vsliveshare
      streetsidesoftware.code-spell-checker
      stkb.rewrap
    ];

    userSettings = {
      explorer.confirmDelete = false;
      workbench.iconTheme = "vscode-icons";
      workbench.startupEditor = "none";
      workbench.sideBar.location = "right";
      editor.fontFamily = "JetBrainsMono Nerd Font, monospace";
      github.gitProtocol = "ssh";
      git.autofetch = true;
      vsicons.dontShowNewVersionMessage = true;
      "[typescriptreact]" = {
        "editor.defaultFormatter" = "esbenp.prettier-vscode";
      };

      "[jsonc]" = {
        "editor.defaultFormatter" = "esbenp.prettier-vscode";
      };

      "[go]" = {
        formatTool = "goimports";
      };
      editor = {
        formatOnSave = true;
        formatOnSaveMode = "file";
      };

      gopls = {
        "formatting.gofumpt" = true;
      };

      vim = {
        enableNeovim = true;
      };

      "cSpell.language" = "en-GB";

      "nix.enableLanguageServer" = true;
      "nix.serverPath" = "nixd";
      "nix.serverSettings" = {
        "nixd" = {
          "eval" = {
          };
          "formatting" = {
            "command" = "alejandra";
          };
          "options" = {
            "enable" = true;
            "target" = {
              "args" = [];
              "installable" = "<flakeref>#nixosConfigurations.<name>.options";
              # "installable" = "<flakeref>#debug.options";
              # "installable" = "<flakeref>#homeConfigurations.<name>.options";
            };
          };
        };
      };
    };
  };
}
