{pkgs, ...}:
pkgs.writeShellApplication {
  name = "rsync-photos-backup";

  runtimeInputs = with pkgs; [rsync coreutils];

  text = ''
    set -euo pipefail

    # Configuration
    SOURCE="$HOME/Pictures/Photos Library.photoslibrary/"
    DEST="/Volumes/storage/pictures/Photos Library.photoslibrary/"
    MOUNT_POINT="/Volumes/storage"

    # Colors for output
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m' # No Color

    log_info() {
      echo -e "''${GREEN}[INFO]''${NC} $1"
    }

    log_warn() {
      echo -e "''${YELLOW}[WARN]''${NC} $1"
    }

    log_error() {
      echo -e "''${RED}[ERROR]''${NC} $1"
    }

    # Check if backup disk is mounted
    if ! mount | grep -q "$MOUNT_POINT"; then
      log_error "Backup disk is not mounted at $MOUNT_POINT"
      log_error "Please insert and mount the backup disk before running this script."
      exit 1
    fi

    log_info "Backup disk is mounted at $MOUNT_POINT"

    # Check if source exists
    if [ ! -d "$SOURCE" ]; then
      log_error "Source Photos library not found at: $SOURCE"
      exit 1
    fi

    log_info "Source Photos library found at: $SOURCE"

    # Create destination directory if it doesn't exist
    DEST_PARENT="$(dirname "$DEST")"
    if [ ! -d "$DEST_PARENT" ]; then
      log_info "Creating destination directory: $DEST_PARENT"
      mkdir -p "$DEST_PARENT"
    fi

    # Warn user about destructive sync
    log_warn "This will perform a 1:1 sync from source to destination."
    log_warn "Files deleted from source WILL BE DELETED from backup."
    log_warn ""
    log_warn "Source: $SOURCE"
    log_warn "Destination: $DEST"
    log_warn ""

    # Ask for confirmation unless --yes flag is provided
    if [[ "''${1:-}" != "--yes" && "''${1:-}" != "-y" ]]; then
      read -r -p "Do you want to continue? [y/N] " response
      case "$response" in
        [yY][eE][sS]|[yY])
          log_info "Starting backup..."
          ;;
        *)
          log_info "Backup cancelled."
          exit 0
          ;;
      esac
    else
      log_info "Starting backup (--yes flag provided)..."
    fi

    # Record start time
    START_TIME=$(date +%s)

    # Build rsync flags
    # -a: archive mode (preserves permissions, timestamps, symlinks, ownership, groups)
    # -H: preserve hard links (Photos library uses hard links extensively)
    # -E: preserve extended attributes (critical for macOS metadata)
    # -X: preserve extended attributes (Linux compatibility, also helps on macOS)
    # --delete: remove files from destination that don't exist in source (1:1 sync)
    # --delete-during: delete files during transfer, not before (safer for interrupted syncs)
    # --info=progress2: show overall progress (not per-file, which is noisy)
    # --stats: print detailed statistics at end
    # -v: verbose output
    # -h: human-readable sizes
    # --protect-args: protect arguments with spaces

    RSYNC_FLAGS=(-aHEX --delete --delete-during --info=progress2 --stats -vh --protect-args)

    # Check for --verify flag (can be in any position)
    for arg in "$@"; do
      if [[ "$arg" == "--verify" ]]; then
        log_info "Checksum verification enabled (this will be slow for large libraries)"
        RSYNC_FLAGS+=(--checksum)
        break
      fi
    done

    if rsync "''${RSYNC_FLAGS[@]}" "$SOURCE" "$DEST"; then

      END_TIME=$(date +%s)
      DURATION=$((END_TIME - START_TIME))
      MINUTES=$((DURATION / 60))
      SECONDS=$((DURATION % 60))

      log_info "Backup completed successfully!"
      log_info "Total time: ''${MINUTES}m ''${SECONDS}s"
    else
      EXIT_CODE=$?
      log_error "Backup failed with exit code: $EXIT_CODE"
      log_error "Please check the error messages above."
      exit $EXIT_CODE
    fi
  '';
}
