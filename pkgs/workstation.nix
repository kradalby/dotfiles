{
  pkgs,
  lib,
  ...
}: {
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
      unstable.colmena
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
      # jujutsu # Temporarily disabled due to rust build issue
      unstable.gotestsum
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
      # unstable.setec
      unstable.squibble
      unstable.tailscale-tools
      viddy
      # mitmproxy
      ollama
      sqldiff
      sql-studio
      zizmor
      nodejs_24
      uv
      mongodb-tools
      cloc
      unstable.prek
      alejandra
      nodePackages.prettier
      shfmt
    ]
    ++ lib.optionals stdenv.isDarwin [
      unstable.lima
      unstable.colima
      terminal-notifier
      syncthing

      # cook-cli

      silicon

      virt-manager
      qemu

      # sql-studio-mac

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
      incus
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
      (writeShellApplication {
        name = "tøm.sh";

        runtimeInputs = with pkgs; [];

        text = ''
          set -euox pipefail

          delete_git_repos_with_remote() {
          	# Define the target directory
          	local base_dir="$HOME/git" # Change this to the target directory if needed

          	# Find all Git repositories and process them
          	find "$base_dir" -type d -name ".git" | while read -r git_dir; do
          		# Move to the repository's root directory
          		local repo_dir
          		repo_dir=$(dirname "$git_dir")
          		cd "$repo_dir" || continue

          		# Get the remote URLs
          		local remote_urls
          		remote_urls=$(git remote -v || true) # Prevent error if no remotes are configured

          		# Check if any remote URL contains "kradalby"
          		if echo "$remote_urls" | grep -q "kradalby"; then
          			echo "Deleting repository: $repo_dir"
          			# Go back to the base directory and delete the repository
          			cd "$base_dir" || exit
          			# rm -rf "$repo_dir"
          			echo "deleting: $repo_dir"
          		else
          			echo "Skipping repository: $repo_dir"
          		fi
          	done
          }

          read -r -p "Are you sure? [y/N] " response
          if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
          	# rm -rf "$HOME/Sync"
          	echo "$HOME/Sync"

            delete_git_repos_with_remote
          else
          	exit 0
          fi
        '';
      })
    ];
}
