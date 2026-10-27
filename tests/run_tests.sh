#!/usr/bin/env bash
#
# run_tests.sh - Simple tests for the scripts in ../scripts.
# Runs locally and in GitHub Actions. Exits non-zero if any test fails.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS="$REPO_ROOT/scripts"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0

check() {
  local name="$1"; shift
  if "$@"; then
    echo "PASS: $name"; PASS=$((PASS + 1))
  else
    echo "FAIL: $name"; FAIL=$((FAIL + 1))
  fi
}

# ---------- backup.sh ----------
mkdir -p "$WORK/src/sub"
echo "hello" > "$WORK/src/file.txt"
echo "nested" > "$WORK/src/sub/nested.txt"
echo "junk" > "$WORK/src/skip.tmp"

"$SCRIPTS/backup.sh" "$WORK/src" "$WORK/backups" 2 > /dev/null
first="$(find "$WORK/backups" -name 'src_*.tar.gz' | head -n1)"

check "backup creates an archive" test -n "$first"
check "archive contains source files" bash -c "tar -tzf '$first' | grep -q 'src/sub/nested.txt'"
check "archive skips excluded files" bash -c "! tar -tzf '$first' | grep -q 'skip.tmp'"
check "backup writes a log" test -s "$WORK/backups/backup.log"

# Run twice more (sleep so timestamps differ) and confirm rotation keeps 2
sleep 1; "$SCRIPTS/backup.sh" "$WORK/src" "$WORK/backups" 2 > /dev/null
sleep 1; "$SCRIPTS/backup.sh" "$WORK/src" "$WORK/backups" 2 > /dev/null
count="$(find "$WORK/backups" -name 'src_*.tar.gz' | wc -l)"
check "rotation keeps only 2 backups (found $count)" test "$count" -eq 2
check "oldest backup was rotated out" test ! -e "$first"

check "backup fails on missing source" bash -c "! '$SCRIPTS/backup.sh' '$WORK/nope' '$WORK/backups' 2 >/dev/null 2>&1"
check "backup rejects invalid KEEP" bash -c "! '$SCRIPTS/backup.sh' '$WORK/src' '$WORK/backups' abc >/dev/null 2>&1"

# ---------- health_check.sh ----------
check "health check passes with generous limits" \
  bash -c "DISK_LIMIT=101 MEM_LIMIT=101 LOAD_LIMIT=9999 '$SCRIPTS/health_check.sh' >/dev/null"
check "health check warns when limits are 0" \
  bash -c "! DISK_LIMIT=0 MEM_LIMIT=0 LOAD_LIMIT=0 '$SCRIPTS/health_check.sh' >/dev/null"

echo
echo "Results: $PASS passed, $FAIL failed"
(( FAIL == 0 ))
