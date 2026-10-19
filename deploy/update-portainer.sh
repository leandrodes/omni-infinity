#!/bin/bash
# Atualiza o módulo Portainer: baixa a imagem mais recente e recria o container.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

if [ "$(id -u)" -ne 0 ]; then err "Execute como root (su -)."; exit 1; fi

PROJECT_DIR="$(omni_project_dir)"
cd "${PROJECT_DIR}/deploy"

say "Baixando a imagem mais recente do Portainer..."
docker compose -f docker-compose.prod.yaml pull portainer

say "Recriando container do Portainer..."
docker compose -f docker-compose.prod.yaml up -d portainer

if command -v caddy >/dev/null 2>&1; then reload_caddy || true; fi

say "Portainer atualizado."
docker compose -f docker-compose.prod.yaml ps portainer
