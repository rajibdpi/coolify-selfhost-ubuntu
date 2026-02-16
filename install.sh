bash -c "$(cat <<'SCRIPT'
set -euo pipefail

if ! grep -q "Ubuntu 24.04" /etc/os-release; then
  echo "❌ This script is intended for Ubuntu 24.04.x"
  exit 1
fi

echo "==> Updating packages & installing base tools..."
sudo apt update -y
sudo apt install -y ca-certificates curl gnupg ufw openssl

echo "==> Installing Docker (official repo)..."
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

UBU_CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${UBU_CODENAME} stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

sudo apt update -y
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo usermod -aG docker "$USER" || true

echo "==> Basic firewall (keep it simple + Coolify-friendly)..."
sudo ufw allow OpenSSH || true
sudo ufw allow 80/tcp || true
sudo ufw allow 443/tcp || true
sudo ufw --force enable || true

echo "==> Installing Coolify (official installer)..."
# Official docs recommend this installer URL:
# https://cdn.coollabs.io/coolify/install.sh
curl -fsSL https://cdn.coollabs.io/coolify/install.sh | sudo bash

echo "==> Writing an 'Ultimate PHP Stack' template (Nginx + PHP-FPM + MariaDB + Redis)..."
STACK_DIR="/opt/coolify-ultimate/php-stack"
sudo mkdir -p "$STACK_DIR"/{nginx,app,storage}
sudo chown -R "$USER":"$USER" "$(dirname "$STACK_DIR")"

cat > "$STACK_DIR/docker-compose.yml" <<'YML'
services:
  nginx:
    image: nginx:alpine
    depends_on:
      - php
    volumes:
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
      - ./app:/var/www/html:ro
      - ./storage:/var/www/html/storage
    # No host ports here (Coolify proxy publishes it)
    # In Coolify: set domain for service "nginx" (container port 80)
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://127.0.0.1/health || exit 1"]
      interval: 10s
      timeout: 3s
      retries: 10

  php:
    image: php:8.3-fpm-alpine
    working_dir: /var/www/html
    environment:
      # Fill these in Coolify (or .env in your app)
      APP_ENV: production
      PHP_MEMORY_LIMIT: 512M
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
    environment:
      MARIADB_DATABASE: app
      MARIADB_USER: app
      MARIADB_PASSWORD: ${MARIADB_PASSWORD:-change_me_strong}
      MARIADB_ROOT_PASSWORD: ${MARIADB_ROOT_PASSWORD:-change_me_root_strong}
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

  location = /health {
    return 200 "ok\n";
  }

  location / {
    try_files $uri $uri/ /index.php?$query_string;
  }

  location ~ \.php$ {
    try_files $uri =404;
    include fastcgi_params;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    fastcgi_pass php:9000;
  }

  client_max_body_size 128m;
}
CONF

# Tiny placeholder so the stack boots immediately
mkdir -p "$STACK_DIR/app/public"
cat > "$STACK_DIR/app/public/index.php" <<'PHP'
<?php
echo "✅ Coolify Ultimate PHP Stack is running.\n";
PHP

echo
echo "=============================="
echo "✅ DONE!"
echo
echo "Coolify installed. Next steps:"
echo "1) Log into Coolify dashboard (your server IP / domain)."
echo "2) Create a new Resource -> Docker Compose."
echo "3) Paste the compose from: $STACK_DIR/docker-compose.yml"
echo "4) Set domain for service: nginx (port 80). Coolify proxy handles SSL."
echo
echo "Template stack path: $STACK_DIR"
echo "=============================="
echo
echo "ℹ️ Note: Docker group change requires re-login (or reboot) to use docker without sudo."
SCRIPT
)"
