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
      # gitutil
      # go-jsonnet
      # grpcurl
      # imapchive
      # logcli
      # nodejs
      # poetry
      # rnix-lsp
      # yarn
      act
      ansible
      bat
      colmena
      difftastic
      dive
      docker
      dyff
      eb
      entr
      exiftool
      eza
      ffmpeg
      gh
      git-absorb
      git-open
      git-toolbelt
      gotestsum
      headscale
      ipcalc
      kubectl
      kubernetes-helm
      nix-init
      nmap
      nodePackages.node2nix
      nurl
      pre-commit
      prettyping
      python312Packages.pipx
      qrencode
      ragenix
      step-cli
      ts-preauthkey
      unstable.setec
      unstable.squibble
      unstable.tailscale-tools
      viddy
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
