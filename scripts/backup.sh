#!/usr/bin/env bash
#
# backup.sh - Back up a folder to a compressed archive and rotate old backups.
#
# Usage:
#   ./backup.sh                          # uses the defaults below
#   ./backup.sh /path/to/source /path/to/backups 7
#
# Arguments (all optional, override the defaults):
#   $1  SOURCE_DIR   folder to back up
#   $2  BACKUP_DIR   where archives are stored
#   $3  KEEP         how many most-recent backups to keep
#
# Designed to be safe under cron: absolute paths, logging, and a lock
# so two runs never overlap.

set -euo pipefail

# ---------- Configuration (defaults) ----------
SOURCE_DIR="${1:-$HOME/newdir}"
BACKUP_DIR="${2:-$HOME/backups}"
KEEP="${3:-7}"
LOG_FILE="${BACKUP_DIR}/backup.log"
LOCK_FILE="/tmp/backup_$(echo "$SOURCE_DIR" | md5sum | cut -c1-8).lock"

# Patterns to exclude from the archive (add your own)
EXCLUDES=(
  "--exclude=*.tmp"
  "--exclude=node_modules"
  "--exclude=.cache"
)

# Cron has a minimal PATH; make sure standard tools are found
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# ---------- Helpers ----------
log() {
  printf '%s [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" "$2" | tee -a "$LOG_FILE"
}

fail() {
  log "ERROR" "$1"
  exit 1
}

# ---------- Pre-flight checks ----------
mkdir -p "$BACKUP_DIR" || { echo "Cannot create $BACKUP_DIR" >&2; exit 1; }

[[ -d "$SOURCE_DIR" ]] || fail "Source folder does not exist: $SOURCE_DIR"
[[ "$KEEP" =~ ^[0-9]+$ && "$KEEP" -ge 1 ]] || fail "KEEP must be a positive integer (got: $KEEP)"

# Prevent overlapping runs
exec 9>"$LOCK_FILE"
flock -n 9 || fail "Another backup of $SOURCE_DIR is already running"

# ---------- Create backup ----------
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
SOURCE_NAME="$(basename "$SOURCE_DIR")"
ARCHIVE="${BACKUP_DIR}/${SOURCE_NAME}_${TIMESTAMP}.tar.gz"
TMP_ARCHIVE="${ARCHIVE}.partial"

# Remove a half-written archive if the script is interrupted
trap 'rm -f "$TMP_ARCHIVE"' EXIT

log "INFO" "Starting backup of $SOURCE_DIR -> $ARCHIVE"

tar -czf "$TMP_ARCHIVE" "${EXCLUDES[@]}" \
    -C "$(dirname "$SOURCE_DIR")" "$SOURCE_NAME" \
  || fail "tar failed"

# Verify the archive is readable before trusting it
tar -tzf "$TMP_ARCHIVE" > /dev/null || fail "Archive verification failed"

mv "$TMP_ARCHIVE" "$ARCHIVE"
trap - EXIT

SIZE="$(du -h "$ARCHIVE" | cut -f1)"
log "INFO" "Backup complete ($SIZE)"

# ---------- Rotate old backups ----------
# List this source's archives newest-first, skip the first $KEEP, delete the rest
mapfile -t OLD < <(
  find "$BACKUP_DIR" -maxdepth 1 -type f -name "${SOURCE_NAME}_*.tar.gz" -printf '%T@ %p\n' \
    | sort -rn | cut -d' ' -f2- | tail -n +$((KEEP + 1))
)

if (( ${#OLD[@]} > 0 )); then
  for f in "${OLD[@]}"; do
    rm -f -- "$f" && log "INFO" "Rotated out: $(basename "$f")"
  done
else
  log "INFO" "No old backups to rotate (keeping $KEEP)"
fi

log "INFO" "Done"
