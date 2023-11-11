{pkgs, ...}: {
  programs.vscode = {
    enable = true;
    enableUpdateCheck = false;

    package = pkgs.unstable.vscodium;

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
      oderwat.indent-rainbow
      redhat.ansible
      vscode-icons-team.vscode-icons
      vscodevim.vim
      jnoortheen.nix-ide
    ];

    userSettings = {
      explorer.confirmDelete = false;
      workbench.iconTheme = "vscode-icons";
      vsicons.dontShowNewVersionMessage = true;
      "[typescriptreact]" = {
        "editor.defaultFormatter" = "esbenp.prettier-vscode";
      };
      editor = {
        formatOnSave = true;
        formatOnSaveMode = "modificationsIfAvailable";
      };

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
