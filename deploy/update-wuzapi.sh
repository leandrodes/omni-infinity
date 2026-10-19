#!/bin/bash
# Atualiza o módulo WuzAPI: atualiza o fork público e recria o container.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

if [ "$(id -u)" -ne 0 ]; then err "Execute como root (su -)."; exit 1; fi

PROJECT_DIR="$(omni_project_dir)"
cd "${PROJECT_DIR}/deploy"

if [ ! -d "wuzapi/.git" ]; then
  err "Módulo WuzAPI não instalado (deploy/wuzapi ausente). Rode install-wuzapi.sh."
  exit 1
fi

say "Atualizando código do WuzAPI..."
git -C wuzapi pull --ff-only || warn "Não foi possível atualizar o fork do WuzAPI (seguindo)."

say "Recriando container do WuzAPI..."
docker compose -f docker-compose.prod.yaml up -d --build wuzapi

if command -v caddy >/dev/null 2>&1; then reload_caddy || true; fi

say "WuzAPI atualizado."
docker compose -f docker-compose.prod.yaml ps wuzapi
