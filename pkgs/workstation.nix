{
  pkgs,
  lib,
  # , flakes
  ...
}: {
  home.packages = with pkgs;
    [
      # act
      # buf
      # go-jsonnet
      # imapchive
      # logcli
      # nodejs
      # poetry
      # rnix-lsp
      # yarn
      ansible
      colmena
      dockfmt
      drone-cli
      dyff
      eb
      editorconfig-checker
      entr
      exiftool
      gh
      git-open
      gitlint
      grpcurl
      hadolint
      headscale
      html-tidy
      ipcalc
      kubectl
      kubernetes-helm
      libiconv # rnix-lsp
      lua53Packages.luadbi-sqlite3 # yank sql
      lua53Packages.luasql-sqlite3 # yank sql
      nmap
      nodePackages.eslint_d
      nodePackages.node2nix
      nodePackages.prettier
      nodejs # ansiblels
      pre-commit
      prettyping
      python310Packages.pylama
      qrencode
      ragenix
      shellcheck
      shellharden
      shfmt
      step-cli
      unstable.dotnet-sdk # omnisharp
      vale
      nurl
      python310Packages.pipx

      # (fenix.complete.withComponents
      #   [
      #     "cargo"
      #     "clippy"
      #     "rust-src"
      #     "rustc"
      #     "rustfmt"
      #   ])

      # gofumpt
      # golangci-lint
      # gox
      # golines

      # null-ls only support 0.4.0, so override
      # to ensure we use stable for now.
      stable.statix

      alejandra
      deadnix

      nixpkgs-fmt
      manix

      # Tailscale stuff
      redo-apenwarr

      clang

      # swiftlint
      # clang-format
      # hclfmt
      docker
    ]
    ++ lib.optionals stdenv.isDarwin [
      lima
      colima
      terminal-notifier
      syncthing

      cook-cli

      silicon

      virt-manager

      (pkgs.writeScriptBin
        "pamtouchfix"
        ''
          #!/run/current-system/sw/bin/bash
          cat <<EOT > /etc/pam.d/sudo
          auth       optional       /opt/homebrew/lib/pam/pam_reattach.so
          auth       sufficient     pam_tid.so
          auth       sufficient     pam_smartcard.so
          auth       required       pam_opendirectory.so
          account    required       pam_permit.so
          password   required       pam_deny.so
          session    required       pam_permit.so
          EOT
        '')
    ]
    ++ lib.optionals stdenv.isLinux [
      # swift
    ];
}
