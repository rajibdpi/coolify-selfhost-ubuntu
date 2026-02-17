#!/usr/bin/env bash
set -euo pipefail

# ====== Config (override via env) ======
SWAP_GB="${SWAP_GB:-2}"                  # 0 দিলে swap skip
ENABLE_UFW="${ENABLE_UFW:-1}"            # 0 দিলে ufw skip
OPEN_8000="${OPEN_8000:-1}"              # 0 দিলে 8000 port খুলবে না
STACK_DIR="${STACK_DIR:-/opt/coolify-ultimate/php-stack}"

# ====== Helpers ======
log(){ echo -e "\n\033[1;32m[OK]\033[0m $*"; }
warn(){ echo -e "\n\033[1;33m[WARN]\033[0m $*"; }
die(){ echo -e "\n\033[1;31m[ERR]\033[0m $*\033[0m" >&2; exit 1; }

# ====== Root check ======
if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  die "Run as root: sudo bash $0  (or pipe to sudo bash)"
fi

# ====== OS check (24.04) ======
. /etc/os-release
if [ "${ID:-}" != "ubuntu" ] || [ "${VERSION_ID:-}" != "24.04" ]; then
  die "This script is intended for Ubuntu 24.04.x (found: ${ID:-?} ${VERSION_ID:-?})"
fi

TARGET_USER="${SUDO_USER:-}"
if [ -z "$TARGET_USER" ] || [ "$TARGET_USER" = "root" ]; then
  warn "SUDO_USER not detected. Docker group add may not work for your login user."
  TARGET_USER="${TARGET_USER:-root}"
fi

export DEBIAN_FRONTEND=noninteractive

log "Updating packages & installing base tools..."
apt update -y
apt upgrade -y
apt install -y ca-certificates curl gnupg ufw openssl wget nano cron

# ====== Install Docker (official repo method) ======
if ! command -v docker >/dev/null 2>&1; then
  log "Installing Docker (official repo)..."
  install -m 0755 -d /etc
