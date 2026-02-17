# 🚀 Coolify Selfhost Ultimate Installer

![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04-orange?style=for-the-badge&logo=ubuntu)
![Docker](https://img.shields.io/badge/Docker-Official-blue?style=for-the-badge&logo=docker)
![Coolify](https://img.shields.io/badge/Coolify-SelfHosted-green?style=for-the-badge)
![Version](https://img.shields.io/github/v/release/rajibdpi/coolify-selfhost-ubuntu?style=for-the-badge)

Production-ready **one-command installer** for self-hosting Coolify on Ubuntu 24.04.

---

## ⚡ One Command Install

Run as normal user (example: `rajib`):

```bash
curl -fsSL https://raw.githubusercontent.com/rajibdpi/coolify-selfhost-ubuntu/main/install.sh | sudo -E bash
```

---

## 🎬 Install Preview

```bash
[OK] Updating packages...
[OK] Installing Docker...
[OK] Configuring Firewall...
[OK] Creating Swap...
[OK] Installing Coolify...
[OK] Writing PHP Stack Template...

==============================
✅ DONE!
Coolify Panel → http://SERVER_IP:8000
==============================
```

---

## 🧱 Architecture Diagram

```
                🌍 Internet
                     │
                     ▼
            ┌─────────────────┐
            │  Traefik Proxy  │
            │    (Coolify)    │
            └─────────────────┘
                     │
      ┌──────────────┼──────────────┐
      ▼              ▼              ▼
 ┌──────────┐   ┌──────────┐   ┌──────────┐
 │   App    │   │ MongoDB  │   │  Redis   │
 │Container │   │ Database │   │  Cache   │
 └──────────┘   └──────────┘   └──────────┘
                     │
                     ▼
               Docker Network
```

---

## 🧰 What This Installer Does

### ✔ System Setup
- Updates Ubuntu packages
- Installs required tools

### ✔ Docker (Official)
- Docker CE install
- Docker service enable
- Adds login user to docker group

### ✔ Security
Firewall (UFW):

- 22 (SSH)
- 80 (HTTP)
- 443 (HTTPS)
- 8000 (Coolify Panel)

### ✔ Stability
- Swap memory (optional)
- Docker log rotation
- Prevents disk full issues

### ✔ Coolify Install
Official installer:

```
https://cdn.coollabs.io/coolify/install.sh
```

---

## 🧩 Generated Stack Template

Installer creates:

```
/opt/coolify-ultimate/php-stack
```

Includes:

- PHP-FPM
- Nginx
- MariaDB
- Redis

Use in Coolify:

```
Projects → Resources → Docker Compose
```

---

## 🌐 Access Coolify

```
http://SERVER_IP:8000
```

---

## 🔐 Docker Permission (Important)

After install:

```bash
logout
```

Login again.

Check:

```bash
docker ps
```

---

## ⚙️ Optional Install Modes

### Swap 4GB

```bash
curl -fsSL https://raw.githubusercontent.com/rajibdpi/coolify-selfhost-ubuntu/main/install.sh | sudo -E env SWAP_GB=4 bash
```

### Disable Firewall

```bash
curl -fsSL https://raw.githubusercontent.com/rajibdpi/coolify-selfhost-ubuntu/main/install.sh | sudo -E env ENABLE_UFW=0 bash
```

---

## 🌍 Recommended DNS Setup

```
coolify.yourdomain.com → SERVER_IP
*.yourdomain.com → SERVER_IP
```

Coolify auto-manages SSL certificates.

---

## 🧠 Production Architecture

```
Ubuntu 24.04
      ↓
Docker Engine
      ↓
Coolify
      ↓
Traefik Reverse Proxy
      ↓
Apps / APIs / Databases
```

---

## 🧯 Troubleshooting

### Docker Permission Error

```bash
newgrp docker
```

---

### Coolify Not Opening

```bash
docker ps
```

---

## 👨‍💻 Author

**Rajib Ahmed**

GitHub: https://github.com/rajibdpi

---

## ⭐ Support

If this project helped you:

➡ Give this repo a ⭐
