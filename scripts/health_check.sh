#!/usr/bin/env bash
#
# health_check.sh - Report basic system health and warn when limits are crossed.
#
# Usage:
#   ./health_check.sh                 # default thresholds
#   DISK_LIMIT=90 MEM_LIMIT=85 ./health_check.sh
#
# Exit codes:
#   0  everything is within limits
#   1  at least one check crossed its threshold (useful for cron/CI alerts)

set -euo pipefail

DISK_LIMIT="${DISK_LIMIT:-80}"   # % used on any mounted filesystem
MEM_LIMIT="${MEM_LIMIT:-80}"     # % of RAM used
LOAD_LIMIT="${LOAD_LIMIT:-$(nproc)}"  # 1-minute load average

STATUS=0

ok()   { printf '  [OK]   %s\n' "$1"; }
warn() { printf '  [WARN] %s\n' "$1"; STATUS=1; }

echo "== System health: $(hostname) @ $(date '+%Y-%m-%d %H:%M:%S') =="
echo "Uptime: $(uptime -p 2>/dev/null || uptime)"
echo

# ---------- Disk ----------
echo "Disk usage (limit ${DISK_LIMIT}%):"
while read -r usage mount; do
  pct="${usage%\%}"
  if (( pct >= DISK_LIMIT )); then
    warn "$mount is ${pct}% full"
  else
    ok "$mount is ${pct}% full"
  fi
done < <(df -P -x tmpfs -x devtmpfs -x squashfs -x overlay 2>/dev/null | awk 'NR>1 {print $5, $6}')
echo

# ---------- Memory ----------
echo "Memory (limit ${MEM_LIMIT}%):"
read -r total available < <(awk '/MemTotal/ {t=$2} /MemAvailable/ {a=$2} END {print t, a}' /proc/meminfo)
mem_pct=$(( (total - available) * 100 / total ))
if (( mem_pct >= MEM_LIMIT )); then
  warn "RAM ${mem_pct}% used"
else
  ok "RAM ${mem_pct}% used"
fi
echo

# ---------- CPU load ----------
echo "CPU load (limit ${LOAD_LIMIT}):"
load1="$(cut -d' ' -f1 /proc/loadavg)"
if awk -v l="$load1" -v m="$LOAD_LIMIT" 'BEGIN {exit !(l >= m)}'; then
  warn "1-min load average is $load1"
else
  ok "1-min load average is $load1"
fi
echo

if (( STATUS == 0 )); then
  echo "Result: all checks passed"
else
  echo "Result: one or more checks need attention"
fi
exit "$STATUS"
