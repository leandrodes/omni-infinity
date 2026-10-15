#!/bin/bash
set -euo pipefail
if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
  apt-get update -y && apt-get install -y -qq curl wget ca-certificates
fi
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
fi
if command -v systemctl >/dev/null 2>&1; then
  systemctl enable --now docker || true
fi
if ! command -v docker compose >/dev/null 2>&1 && ! docker-compose --version >/dev/null 2>&1; then
  echo "Instalando docker compose plugin..."
  apt-get update -y && apt-get install -y -qq docker-compose-plugin || true
fi
if ! command -v git >/dev/null 2>&1; then
  apt-get update -y && apt-get install -y -qq git
fi
mkdir -p /opt
cd /opt
rm -rf omni-infinity
git clone https://github.com/leandrodes/omni-infinity.git
cd omni-infinity/deploy
exec bash install.sh
