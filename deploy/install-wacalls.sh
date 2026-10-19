#!/bin/bash
# Instala o módulo WaCalls (chamadas de voz WhatsApp não oficial) de forma isolada.
# - Baixa o fork público em deploy/wacalls
# - Ativa o profile "wacalls" no docker compose
# - Gera WACALLS_API_KEY (se ausente) e ajusta o .env
# - Adiciona o bloco do domínio no Caddy do host e recarrega
# - Sobe o container do WaCalls
#
# Observação: o WaCalls é um app standalone (Go+React). Os campos WACALLS_ENDPOINT
# e WACALLS_API_KEY no Omni-Channel Infinity (Super Admin > WhatsApp não oficial)
# ficam prontos para uma futura integração de canal; por ora preenchem-se
# manualmente.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

if [ "$(id -u)" -ne 0 ]; then err "Execute como root (su -)."; exit 1; fi

PROJECT_DIR="$(omni_project_dir)"
ENV_FILE="${PROJECT_DIR}/deploy/.env"
COMPOSE_FILE="docker-compose.prod.yaml"
WACALLS_WEB_URL="http://wacalls:8080"

say "Instalando módulo WaCalls em ${PROJECT_DIR}"
if [ ! -f "$ENV_FILE" ]; then err ".env não encontrado em ${ENV_FILE}. Rode o install.sh primeiro."; exit 1; fi

read -rp "Domínio público do WaCalls (ex.: wacalls.seudominio.com.br): " WACALLS_DOMAIN
if [ -z "$WACALLS_DOMAIN" ]; then err "Domínio é obrigatório."; exit 1; fi

ensure_repo "${PROJECT_DIR}/deploy/wacalls" "https://github.com/leandrodes/wacalls.git" "WaCalls" || exit 1

ensure_env_var "$ENV_FILE" "WACALLS_API_KEY" "$(gen_hex 32)"
ensure_env_var "$ENV_FILE" "WACALLS_ENDPOINT" "$WACALLS_WEB_URL"
ensure_env_var "$ENV_FILE" "WACALLS_MAX_CALLS" "8"
ensure_compose_profile "$ENV_FILE" "wacalls"

ensure_caddy_block "$WACALLS_DOMAIN" "127.0.0.1:8082" "wacalls" || true

cd "${PROJECT_DIR}/deploy"
say "Subindo container do WaCalls..."
docker compose -f "$COMPOSE_FILE" up -d --build wacalls

APIKEY="$(grep '^WACALLS_API_KEY=' "$ENV_FILE" | head -1 | cut -d= -f2-)"
echo
say "WaCalls instalado."
echo "  URL pública:        https://${WACALLS_DOMAIN}"
echo "  Endpoint interno:   ${WACALLS_WEB_URL}"
echo "  X-API-Key:          ${APIKEY}"
echo
say "Observação: a integração de chamadas dentro do Omni-Channel Infinity é uma"
say "evolução futura. Os campos WACALLS_ENDPOINT/WACALLS_API_KEY já estão prontos"
say "no Super Admin para quando ela existir."
