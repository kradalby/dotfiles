{
  pkgs,
  lib,
  # , flakes
  ...
}: let
  sql-studio-mac = pkgs.sql-studio.overrideAttrs (o: {
    nativeBuildInputs = [pkgs.darwin.apple_sdk.frameworks.SystemConfiguration] ++ o.nativeBuildInputs;
  });
in {
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
      # grpcurl
      # nodejs # ansiblels
      # yarn
      # gitutil
      ansible
      colmena
      dyff
      eb
      entr
      exiftool
      gh
      git-open
      headscale
      ipcalc
      kubectl
      kubernetes-helm
      nmap
      nodePackages.node2nix
      pre-commit
      prettyping
      qrencode
      ragenix
      step-cli
      nurl
      nix-init
      act
      dive
      gotestsum
      difftastic
      git-absorb
      bat
      viddy
      eza

      unstable.setec
      unstable.squibble
      unstable.tailscale-tools
      ffmpeg

      ts-preauthkey

      python312Packages.pipx

      docker

      clang
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

      sql-studio-mac

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
            "-filecreatedate<datetimeoriginal" \
            "-filemodifydate<datetimeoriginal" \
            -overwrite_original \
            -Copyright="Photo by $author. All rights to the respective authors." \
            -Creator="$author" \
            -Owner="$author" \
            -ownername="$author" \
            "$img"
        '';
      })
    ];
}
