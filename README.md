# Bash Scripts – Phase 1

![CI](https://github.com/YOUR_USERNAME/bash-scripts/actions/workflows/ci.yml/badge.svg)

A small collection of practical Bash scripts for Linux system administration, with automated linting and tests on every push.

## Scripts

| Script | What it does |
|---|---|
| [`scripts/backup.sh`](scripts/backup.sh) | Backs up a folder to a timestamped `.tar.gz`, verifies it, and keeps only the newest N backups |
| [`scripts/health_check.sh`](scripts/health_check.sh) | Reports disk, memory and CPU load, and exits non-zero when a threshold is crossed |

## Getting started

```bash
git clone https://github.com/YOUR_USERNAME/bash-scripts.git
cd bash-scripts
chmod +x scripts/*.sh tests/*.sh
```

## Usage

### backup.sh

```bash
./scripts/backup.sh <source_dir> <backup_dir> <keep>

# Example: back up ~/projects to ~/backups, keep the last 7
./scripts/backup.sh ~/projects ~/backups 7
```

Features:
- Timestamped archives: `projects_2026-10-27_02-30-00.tar.gz`
- Integrity check before the archive is kept
- Rotation of old backups
- Logging to `<backup_dir>/backup.log`
- Lock file so overlapping cron runs can't collide
- Configurable exclude patterns (`EXCLUDES` at the top of the script)

Restore a backup:

```bash
tar -xzf ~/backups/projects_2026-10-27_02-30-00.tar.gz -C /restore/path
```

### health_check.sh

```bash
./scripts/health_check.sh

# Custom thresholds
DISK_LIMIT=90 MEM_LIMIT=85 LOAD_LIMIT=4 ./scripts/health_check.sh
```

| Variable | Default | Meaning |
|---|---|---|
| `DISK_LIMIT` | `80` | Warn when any filesystem is at least this % full |
| `MEM_LIMIT` | `80` | Warn when RAM usage is at least this % |
| `LOAD_LIMIT` | number of CPUs | Warn when the 1-minute load average reaches this |

Exits `0` when all checks pass, `1` otherwise.

## Scheduling with cron

```bash
crontab -e
```

```cron
# Daily backup at 02:30
30 2 * * * /home/USER/bash-scripts/scripts/backup.sh /home/USER/projects /home/USER/backups 7 >> /home/USER/backups/cron.log 2>&1

# Health check every hour
0 * * * * /home/USER/bash-scripts/scripts/health_check.sh >> /home/USER/health.log 2>&1
```

Use absolute paths in cron. On WSL, start cron first with `sudo service cron start`.

## Testing

```bash
./tests/run_tests.sh
```

## CI

GitHub Actions ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)) runs on every push to `main` and on pull requests:

1. **ShellCheck** – lints every `.sh` file
2. **Tests** – runs `tests/run_tests.sh`

## Project structure

```
.
├── .github/workflows/ci.yml   # GitHub Actions pipeline
├── scripts/
│   ├── backup.sh
│   └── health_check.sh
├── tests/
│   └── run_tests.sh
└── README.md
```
