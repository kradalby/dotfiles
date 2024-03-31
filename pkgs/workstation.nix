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
      nurl
      nix-init
      python310Packages.pipx
      # gitutil
      act
      dive
      gotestsum
      difftastic
      setec
      squibble
      tailscale-tools

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
    ]
    ++ lib.optionals stdenv.isDarwin [
      lima
      unstable.colima
      terminal-notifier
      syncthing

      # cook-cli

      silicon

      virt-manager
      qemu

      # We cant use the newest docker on macOS yet
      docker

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
      docker
    ]
    ++ [
      (writeShellApplication {
        name = "exif-set-photographer";

        runtimeInputs = with pkgs; [exiftool];

        text = ''
          if [ "$#" -ne 2 ]; then
            echo "Incorrect number of arguments"
            echo "USAGE: $0 <author> <image file>"
            exit 1
          fi

          author=$1
          img=$2

          exiftool -use MWG \
            -Copyright="Image by $author. All rights to the respective authors." \
            -Creator="$author" \
            -Owner="$author" \
            -ownername="$author" \
            "$img"
        '';
      })
    ];
}
