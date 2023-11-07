{pkgs, ...}: {
  programs.vscode = {
    enable = true;
    enableUpdateCheck = false;

    package = pkgs.unstable.vscodium;

    mutableExtensionsDir = true;
    extensions = with pkgs.vscode-marketplace; [
      arrterian.nix-env-selector
      bbenoist.nix
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
    ];

    userSettings = {
      workbench.iconTheme = "vscode-icons";
      "[typescriptreact]" = {
        "editor.defaultFormatter" = "esbenp.prettier-vscode";
      };
      editor = {
        formatOnSave = true;
        formatOnSaveMode = "modificationsIfAvailable";
      };
    };
  };
}
