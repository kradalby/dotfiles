{ pkgs, ... }:
pkgs.writeShellApplication {
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
}
