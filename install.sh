#!/usr/bin/env bash
set -euo pipefail

# ================================
# Coolify Selfhost Ultimate Installer (Ubuntu 24.04)
# - Docker (official repo)
# - UFW ports (22/80/443/8000)
# - Optional swap
# - Install Coolify (official installer)
# - After Coolify: set Docker log rotation (disk-safe)
# - Create Laravel/PHP stack template (Nginx+PHP+MariaDB+Redis)
# ================================

# ---- Config (override via env) ----
SWAP_GB="${SWAP_GB:-2}"                  # 0 = skip swap
ENABLE_UFW="${ENABLE_UFW:-1}"            # 0 = skip ufw
OPEN_8000="${OPEN_8000:-1}"              # 0 = don't open 8000
STACK_DIR="${STACK_DIR:-/opt/coolify-ultimate/php-stack}"

# If Coolify tries to modify docker network pool without asking:
# You can FORCE override (Coolify installer message suggested this)
DOCKER_POOL_FORCE_OVERRIDE="${DOCKER_POOL_FORCE_OVERRIDE:-false}"

log(){ echo -e "\n\033[1;32m[OK]\033[0m $*"; }
warn(){ echo -e "\n\033[1;33m[WARN]\033[0m $*"; }
die(){ echo -e "\n\033[1;31m[ERR]\033[0m $*\033[0m" >&2; exit 1; }

# ---- Root check ----
if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  die "Run as: sudo bash install.sh  (or: curl ... | sudo bash)"
fi

# ---- OS check ----
. /etc/os-release
if [ "${ID:-}" != "ubuntu" ] || [ "${VERSION_ID:-}" != "24.04" ]; then
  die "This script is intended for Ubuntu 24.04.x (found: ${ID:-?} ${VERSION_ID:-?})"
fi

TARGET_USER="${SUDO_USER:-root}"
if [ -z "${SUDO_USER:-}" ] || [ "$TARGET_USER" = "root" ]; then
  warn "SUDO_USER not detected. Docker group add may not apply to your login user."
fi

export DEBIAN_FRONTEND=noninteractive

log "Updating packages & installing base tools..."
apt update -y
apt upgrade -y
apt install -y ca-certificates curl gnupg ufw openssl wget nano cron

# ---- Install Docker (official repo method) ----
if ! command -v docker >/dev/null 2>&1; then
  log "Installing Docker (official repo)..."
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  UBU_CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${UBU_CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list

  apt update -y
  apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
else
  log "Docker already installed."
fi

log "Enabling & starting Docker..."
systemctl enable docker
systemctl reset-failed docker || true
systemctl restart docker
sleep 2

# ---- Add login user to docker group ----
if id "$TARGET_USER" >/dev/null 2>&1; then
  if id -nG "$TARGET_USER" | grep -qw docker; then
    log "User '$TARGET_USER' already in docker group."
  else
    log "Adding '$TARGET_USER' to docker group..."
    usermod -aG docker "$TARGET_USER" || true
    warn "Logout/login required for docker group to apply for '$TARGET_USER'."
  fi
fi

# ---- Firewall ----
if [ "$ENABLE_UFW" = "1" ]; then
  log "Configuring UFW firewall..."
  ufw allow OpenSSH || true
  ufw allow 80/tcp || true
  ufw allow 443/tcp || true
  if [ "$OPEN_8000" = "1" ]; then
    ufw allow 8000/tcp || true
  fi
  ufw --force enable || true
  ufw status || true
else
  warn "Skipping UFW (ENABLE_UFW=0)."
fi

# ---- Swap (optional) ----
HAS_SWAP="$(swapon --show | wc -l | tr -d ' ')"
if [ "$SWAP_GB" -gt 0 ] 2>/dev/null && [ "$HAS_SWAP" -le 1 ] && [ ! -f /swapfile ]; then
  log "Creating ${SWAP_GB}GB swapfile..."
  fallocate -l "${SWAP_GB}G" /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=$((SWAP_GB*1024))
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  grep -q "^/swapfile" /etc/fstab || echo "/swapfile none swap sw 0 0" >> /etc/fstab
  log "Swap enabled."
else
  log "Swap already present or disabled. Skipping."
fi

# ---- Install Coolify ----
log "Installing Coolify (official installer)..."
export DOCKER_POOL_FORCE_OVERRIDE
curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash

# ---- After Coolify: Docker log rotation (disk-safe) ----
log "Setting Docker log rotation..."
mkdir -p /etc/docker
if [ -f /etc/docker/daemon.json ]; then
  cp /etc/docker/daemon.json "/etc/docker/daemon.json.bak.$(date +%F-%H%M%S)" || true
fi

# Keep it minimal to avoid breaking Coolify's own docker settings.
cat >/etc/docker/daemon.json <<'JSON'
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" }
}
JSON

systemctl reset-failed docker || true
systemctl restart docker
sleep 2

# ---- Write PHP stack template ----
log "Writing Compose template (Nginx + PHP-FPM + MariaDB + Redis)..."
mkdir -p "$STACK_DIR"/{nginx,app,storage}

# Ownership so rajib can edit
if id "$TARGET_USER" >/dev/null 2>&1; then
  chown -R "$TARGET_USER":"$TARGET_USER" "$(dirname "$STACK_DIR")" || true
fi

# Secrets
ENV_FILE="$STACK_DIR/.env"
if [ ! -f "$ENV_FILE" ]; then
  MARIADB_PASSWORD="$(openssl rand -base64 24 | tr -d '\n')"
  MARIADB_ROOT_PASSWORD="$(openssl rand -base64 28 | tr -d '\n')"
  cat > "$ENV_FILE" <<EOF
MARIADB_PASSWORD=${MARIADB_PASSWORD}
MARIADB_ROOT_PASSWORD=${MARIADB_ROOT_PASSWORD}
EOF
  chmod 600 "$ENV_FILE"
  log "Generated DB secrets at: $ENV_FILE"
else
  log ".env already exists at $ENV_FILE (keeping existing secrets)."
fi

cat > "$STACK_DIR/docker-compose.yml" <<'YML'
services:
  nginx:
    image: nginx:alpine
    depends_on: [php]
    volumes:
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
      - ./app:/var/www/html:ro
      - ./storage:/var/www/html/storage
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://127.0.0.1/health || exit 1"]
      interval: 10s
      timeout: 3s
      retries: 10

  php:
    image: php:8.3-fpm-alpine
    working_dir: /var/www/html
    volumes:
      - ./app:/var/www/html
      - ./storage:/var/www/html/storage
    healthcheck:
      test: ["CMD-SHELL", "php -v >/dev/null 2>&1 || exit 1"]
      interval: 15s
      timeout: 5s
      retries: 10

  mariadb:
    image: mariadb:11
    command: ["--character-set-server=utf8mb4","--collation-server=utf8mb4_unicode_ci"]
    env_file: ./.env
    environment:
      MARIADB_DATABASE: app
      MARIADB_USER: app
      MARIADB_PASSWORD: ${MARIADB_PASSWORD}
      MARIADB_ROOT_PASSWORD: ${MARIADB_ROOT_PASSWORD}
    volumes:
      - mariadb_data:/var/lib/mysql
    healthcheck:
      test: ["CMD-SHELL", "mariadb-admin ping -h 127.0.0.1 -uroot -p$${MARIADB_ROOT_PASSWORD} --silent"]
      interval: 10s
      timeout: 5s
      retries: 20

  redis:
    image: redis:7-alpine
    command: ["redis-server","--appendonly","yes"]
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD-SHELL", "redis-cli ping | grep -q PONG"]
      interval: 10s
      timeout: 3s
      retries: 20

volumes:
  mariadb_data:
  redis_data:
YML

cat > "$STACK_DIR/nginx/default.conf" <<'CONF'
server {
  listen 80;
  server_name _;
  root /var/www/html/public;
  index index.php index.html;

  location = /health { return 200 "ok\n"; }

  location / { try_files $uri $uri/ /index.php?$query_string; }

  location ~ \.php$ {
    try_files $uri =404;
    include fastcgi_params;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    fastcgi_pass php:9000;
  }

  client_max_body_size 128m;
}
CONF

mkdir -p "$STACK_DIR/app/public"
cat > "$STACK_DIR/app/public/index.php" <<'PHP'
<?php echo "✅ Coolify Ultimate PHP Stack is running.\n";
PHP

IP="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"

echo
echo "=============================="
echo "✅ DONE!"
echo "Coolify Panel: http://${IP:-YOUR_SERVER_IP}:8000"
echo "Template path: $STACK_DIR"
echo
echo "Coolify -> Projects/Resources -> Docker Compose:"
echo "  - Paste $STACK_DIR/docker-compose.yml content"
echo "  - Add env vars from $STACK_DIR/.env"
echo "  - Assign domain to service: nginx (port 80). Coolify proxy will do SSL."
echo
echo "ℹ️ Logout/login required for docker group (user: $TARGET_USER)."
echo "=============================="
