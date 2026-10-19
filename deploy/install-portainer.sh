#!/bin/bash
# Instala o módulo Portainer (painel de gerenciamento de containers) de forma isolada.
# - Ativa o profile "portainer" no docker compose
# - Adiciona o bloco do domínio no Caddy do host e recarrega
# - Sobe o container do Portainer
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

if [ "$(id -u)" -ne 0 ]; then err "Execute como root (su -)."; exit 1; fi

PROJECT_DIR="$(omni_project_dir)"
ENV_FILE="${PROJECT_DIR}/deploy/.env"
COMPOSE_FILE="docker-compose.prod.yaml"

say "Instalando módulo Portainer em ${PROJECT_DIR}"
if [ ! -f "$ENV_FILE" ]; then err ".env não encontrado em ${ENV_FILE}. Rode o install.sh primeiro."; exit 1; fi

read -rp "Domínio público do Portainer (ex.: painel.seudominio.com.br): " PORTAINER_DOMAIN
if [ -z "$PORTAINER_DOMAIN" ]; then err "Domínio é obrigatório."; exit 1; fi

ensure_compose_profile "$ENV_FILE" "portainer"
ensure_caddy_block "$PORTAINER_DOMAIN" "127.0.0.1:9000" "portainer" || true

cd "${PROJECT_DIR}/deploy"
say "Subindo container do Portainer..."
docker compose -f "$COMPOSE_FILE" up -d portainer

echo
say "Portainer instalado em https://${PORTAINER_DOMAIN}"
say "Crie o usuário administrador no primeiro acesso (a senha é definida na tela inicial)."
