

# Coolify Self-Host Ubuntu

Automated installation script for **Coolify** on Ubuntu 24.04 with Docker, PHP-FPM stack (MariaDB, Redis, Nginx), and firewall configuration.

## Prerequisites

- Ubuntu 24.04.x
- Root access (sudo)
- Minimum 2GB RAM (configurable swap)

## Quick Start

```bash
sudo bash install.sh
```

## Configuration

Override defaults via environment variables:

```bash
SWAP_GB=4 ENABLE_UFW=1 OPEN_8000=1 sudo bash install.sh
```

| Variable | Default | Description |
|----------|---------|-------------|
| `SWAP_GB` | `2` | Swap size in GB (0 to skip) |
| `ENABLE_UFW` | `1` | Enable firewall (0 to skip) |
| `OPEN_8000` | `1` | Open port 8000 (0 to skip) |
| `STACK_DIR` | `/opt/coolify-ultimate/php-stack` | Template installation path |

## What Gets Installed

- **Docker** (official repository)
- **Coolify** (self-hosted panel)
- **PHP Stack** with Docker Compose:
    - Nginx (Alpine)
    - PHP 8.3-FPM (Alpine)
    - MariaDB 11
    - Redis 7
- **UFW Firewall** (ports 22, 80, 443, optionally 8000)
- **Swap** (optional, if needed)

## After Installation

1. Access Coolify at: `http://YOUR_SERVER_IP:8000`
2. Deploy the PHP stack via Coolify UI using `/opt/coolify-ultimate/php-stack/docker-compose.yml`
3. Database credentials are auto-generated in `.env`
4. **Logout/login required** for Docker group to take effect

## Firewall Ports

- **22** (SSH)
- **80** (HTTP)
- **443** (HTTPS)
- **8000** (Coolify Panel, optional)
you create a README.md, but I need to see the contents of your `install.sh` file first. Could you please share the script so I can understand:

- What the project does
- Installation steps and requirements
- Dependencies
- Configuration options
- Usage instructions

Please paste the contents of your `install.sh` file, and I'll generate an appropriate README based on it.
