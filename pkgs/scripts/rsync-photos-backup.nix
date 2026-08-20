{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "rsync-photos-backup";

  runtimeInputs = with pkgs; [
    rsync
    openssh
    coreutils
    gnugrep
  ];

  text = ''
    # Configuration
    SOURCE="$HOME/Pictures/Photos Library.photoslibrary/"
    LOCAL_DEST="/Volumes/storage/pictures/Photos Library.photoslibrary/"
    MOUNT_POINT="/Volumes/storage"

    # Remote host aliases -> fqdn. Keep the sync path identical on every
    # target: /storage/pictures/Photos Library.photoslibrary/
    declare -A HOST_MAP=(
      ["ldn"]="storage.ldn"
      ["tjoda"]="core.tjoda"
    )

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

    usage() {
      echo "Usage: $(basename "$0") [--remote ldn|tjoda] [--verify] [--yes|-y]"
      echo ""
      echo "  (no flags)      Backup to local disk at $MOUNT_POINT"
      echo "  --remote ldn    Backup to storage.ldn over ssh"
      echo "  --remote tjoda  Backup to core.tjoda over ssh"
      echo "  --verify        Enable rsync checksum verification (slow)"
      echo "  --yes, -y       Skip the confirmation prompt"
    }

    # ---------- arg parsing ----------
    MODE="local" # local | remote
    SITE=""      # ldn or tjoda (remote only)
    VERIFY=false
    ASSUME_YES=false

    while [[ $# -gt 0 ]]; do
      case "$1" in
        --remote)
          MODE="remote"
          shift
          if [[ $# -eq 0 || "$1" == --* ]]; then
            log_error "--remote requires a site: ldn or tjoda"
            exit 1
          fi
          SITE="$1"
          shift
          ;;
        --local)
          MODE="local"
          shift
          ;;
        --verify)
          VERIFY=true
          shift
          ;;
        --yes | -y)
          ASSUME_YES=true
          shift
          ;;
        -h | --help)
          usage
          exit 0
          ;;
        *)
          usage
          log_error "Unknown argument: $1"
          exit 1
          ;;
      esac
    done

    # Validate site for remote mode
    if [[ "$MODE" == "remote" ]]; then
      if [[ -z "''${HOST_MAP[$SITE]+set}" ]]; then
        log_error "Unknown site '$SITE' (expected ldn|tjoda)"
        exit 1
      fi
    fi

    # Resolve destination based on mode
    if [[ "$MODE" == "local" ]]; then
      DEST="$LOCAL_DEST"
      DEST_TYPE="local mount"
    else
      HOST="''${HOST_MAP[$SITE]}"
      DEST="''${USER}@''${HOST}:/storage/pictures/Photos Library.photoslibrary/"
      DEST_TYPE="remote (ssh -> $HOST)"
    fi

    # Safety: local mode requires disk mount check + source existence
    if [[ "$MODE" == "local" ]]; then
      if ! mount | grep -q "$MOUNT_POINT"; then
        log_error "Backup disk is not mounted at $MOUNT_POINT"
        log_error "Please insert and mount the backup disk before running this script."
        exit 1
      fi
      log_info "Backup disk is mounted at $MOUNT_POINT"
    fi

    if [ ! -d "$SOURCE" ]; then
      log_error "Source Photos library not found at: $SOURCE"
      exit 1
    fi
    log_info "Source Photos library found at: $SOURCE"

    if [[ "$MODE" == "local" ]]; then
      # Create destination directory if it doesn't exist
      DEST_PARENT="$(dirname "$DEST")"
      if [ ! -d "$DEST_PARENT" ]; then
        log_info "Creating destination directory: $DEST_PARENT"
        mkdir -p "$DEST_PARENT"
      fi
    else
      # Safety: remote mode requires the exact parent directory to already
      # exist on the far end. Refuse to create it ourselves — a typo in the
      # host map or path must fail loudly, not silently create a new tree in
      # the wrong place over ssh.
      if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$HOST" test -d "/storage/pictures"; then
        log_error "Remote path does not exist (or is unreachable) on $HOST:"
        log_error "  /storage/pictures/"
        log_error "Create the directory on $HOST and try again."
        exit 1
      fi
      log_info "Confirmed /storage/pictures/ exists on $HOST"
    fi

    # Warn user about destructive sync
    log_warn ""
    log_warn "This will perform a 1:1 sync from source to destination."
    log_warn "Files deleted from source WILL BE DELETED from backup."
    log_warn ""
    log_warn "Mode:        $MODE"
    log_warn "Source:      $SOURCE"
    log_warn "Destination: $DEST"
    log_warn ""

    # Ask for confirmation unless --yes flag is provided
    if [[ "$ASSUME_YES" != true ]]; then
      read -r -p "Do you want to continue? [y/N] " response
      case "$response" in
        [yY][eE][sS] | [yY])
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
    # -E: preserve extended attributes (critical for macOS metadata, local only)
    # -X: preserve extended attributes (Linux compatibility, also helps on macOS)
    # -z: compress during transfer (remote only, saves bandwidth over ssh)
    # --delete: remove files from destination that don't exist in source (1:1 sync)
    # --delete-during: delete files during transfer, not before (safer for interrupted syncs)
    # --info=progress2: show overall progress (not per-file, which is noisy)
    # --stats: print detailed statistics at end
    # -v: verbose output
    # -h: human-readable sizes
    # --protect-args: protect arguments with spaces

    RSYNC_FLAGS=(-aH --delete --delete-during --info=progress2 --stats -vh --protect-args)

    if [[ "$MODE" == "local" ]]; then
      RSYNC_FLAGS+=(-EX)
    else
      RSYNC_FLAGS+=(-X -z -e "ssh -o ConnectTimeout=10 -o BatchMode=yes")
    fi

    if [[ "$VERIFY" == true ]]; then
      log_info "Checksum verification enabled (this will be slow for large libraries)"
      RSYNC_FLAGS+=(--checksum)
    fi

    if rsync "''${RSYNC_FLAGS[@]}" "$SOURCE" "$DEST"; then

      END_TIME=$(date +%s)
      DURATION=$((END_TIME - START_TIME))
      MINUTES=$((DURATION / 60))
      SECONDS=$((DURATION % 60))

      log_info "Backup to $DEST_TYPE completed successfully!"
      log_info "Total time: ''${MINUTES}m ''${SECONDS}s"
    else
      EXIT_CODE=$?
      log_error "Backup to $DEST_TYPE failed with exit code: $EXIT_CODE"
      log_error "Please check the error messages above."
      exit $EXIT_CODE
    fi
  '';
}
