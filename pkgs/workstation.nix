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
      drone-cli
      dyff
      eb
      entr
      exiftool
      gh
      git-open
      grpcurl
      headscale
      ipcalc
      kubectl
      kubernetes-helm
      nmap
      nodePackages.node2nix
      nodePackages.prettier
      nodejs # ansiblels
      pre-commit
      prettyping
      qrencode
      ragenix
      step-cli
      unstable.dotnet-sdk # omnisharp
      nurl
      nix-init
      python310Packages.pipx
      # gitutil
      act
      devenv
      dive

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

      # Tailscale stuff
      redo-apenwarr

      clang

      # swiftlint
      # clang-format
      # hclfmt
      docker
    ]
    ++ lib.optionals stdenv.isDarwin [
      unstable.lima
      unstable.colima
      terminal-notifier
      syncthing

      cook-cli

      silicon

      virt-manager
      qemu

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
