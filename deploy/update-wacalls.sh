#!/bin/bash
# Atualiza o módulo WaCalls: atualiza o fork público e recria o container.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

if [ "$(id -u)" -ne 0 ]; then err "Execute como root (su -)."; exit 1; fi

PROJECT_DIR="$(omni_project_dir)"
cd "${PROJECT_DIR}/deploy"

if [ ! -d "wacalls/.git" ]; then
  err "Módulo WaCalls não instalado (deploy/wacalls ausente). Rode install-wacalls.sh."
  exit 1
fi

say "Atualizando código do WaCalls..."
git -C wacalls pull --ff-only || warn "Não foi possível atualizar o fork do WaCalls (seguindo)."

say "Recriando container do WaCalls..."
docker compose -f docker-compose.prod.yaml up -d --build wacalls

if command -v caddy >/dev/null 2>&1; then reload_caddy || true; fi

say "WaCalls atualizado."
docker compose -f docker-compose.prod.yaml ps wacalls
