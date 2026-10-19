#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

say_r() { echo -e "\e[1;36m[Omni-Infinity-Reconfigure]\e[0m $*"; }

say_r "Reconfigurando firewall/Fail2Ban (preserva domínios/.env/Caddyfile existentes)"
cd "$PROJECT_DIR/deploy"

read -rp "Configurar UFW? [s/N]: " CFG_UFW
CFG_UFW=${CFG_UFW:-N}
read -rp "Configurar Fail2Ban? [s/N]: " CFG_FAIL2BAN
CFG_FAIL2BAN=${CFG_FAIL2BAN:-N}

CFG_WACALLS=N
if [ -f .env ] && grep -q "WACALLS_API_KEY" .env; then
  CFG_WACALLS=S
fi

if [[ "$CFG_UFW" =~ ^[Ss]$ ]]; then
  if ! command -v ufw >/dev/null 2>&1; then
    apt-get update -y && apt-get install -y ufw || true
  fi
  if command -v ufw >/dev/null 2>&1; then
    ufw default deny incoming >/dev/null 2>&1 || true
    ufw default allow outgoing >/dev/null 2>&1 || true
    ufw allow 22/tcp >/dev/null 2>&1 || true
    ufw allow 80/tcp >/dev/null 2>&1 || true
    ufw allow 443/tcp >/dev/null 2>&1 || true
    echo "y" | ufw enable >/dev/null 2>&1 || true
    say_r "✓ UFW configurado"
  fi
fi

if [[ "$CFG_FAIL2BAN" =~ ^[Ss]$ ]]; then
  if ! command -v fail2ban-client >/dev/null 2>&1; then
    apt-get update -y && apt-get install -y fail2ban >/dev/null 2>&1 || true
  fi
  mkdir -p /etc/fail2ban/jail.d
  mkdir -p /etc/fail2ban/filter.d
  mkdir -p /var/log/caddy
  touch /var/log/caddy/access.log
  chown -R caddy:caddy /var/log/caddy 2>/dev/null || true
  if [ -f "$SCRIPT_DIR/fail2ban/filter.d/caddy-auth.conf" ]; then
    cp "$SCRIPT_DIR/fail2ban/filter.d/caddy-auth.conf" /etc/fail2ban/filter.d/caddy-auth.conf
    chmod 644 /etc/fail2ban/filter.d/caddy-auth.conf
  fi
  cat > /etc/fail2ban/jail.d/omni-infinity.conf << JAIL
[sshd]
enabled = true
backend = systemd
journalmatch = _COMM=sshd
port = ssh
maxretry = 5
bantime = 1h
findtime = 10m

[caddy-auth]
enabled = true
filter = caddy-auth
port = http,https
logpath = /var/log/caddy/*.log
maxretry = 5
bantime = 1h
findtime = 10m
JAIL
  systemctl enable --now fail2ban >/dev/null 2>&1 || fail2ban-client start >/dev/null 2>&1 || true
  say_r "✓ Fail2Ban configurado"
fi

say_r "Finalizado."
