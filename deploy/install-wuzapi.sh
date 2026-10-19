#!/bin/bash
# Instala o módulo WuzAPI (WhatsApp não oficial) de forma isolada.
# - Baixa o fork público em deploy/wuzapi
# - Ativa o profile "wuzapi" no docker compose
# - Gera WUZAPI_ADMIN_TOKEN (se ausente) e ajusta o .env
# - Adiciona o bloco do domínio no Caddy do host e recarrega
# - Sobe o container do WuzAPI
#
# IMPORTANTE (configuração manual): depois de instalar, um SUPER ADMIN precisa
# informar, no Omni-Channel Infinity (Super Admin > Configurações > WhatsApp não
# oficial), o "WuzAPI Endpoint" e o "WuzAPI Admin Token". A caixa de entrada
# "WhatsApp Não Oficial" só fica disponível após isso.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

if [ "$(id -u)" -ne 0 ]; then err "Execute como root (su -)."; exit 1; fi

PROJECT_DIR="$(omni_project_dir)"
ENV_FILE="${PROJECT_DIR}/deploy/.env"
COMPOSE_FILE="docker-compose.prod.yaml"
WUZAPI_WEB_URL="http://wuzapi:8080"

say "Instalando módulo WuzAPI em ${PROJECT_DIR}"
if [ ! -f "$ENV_FILE" ]; then err ".env não encontrado em ${ENV_FILE}. Rode o install.sh primeiro."; exit 1; fi

read -rp "Domínio público do WuzAPI (ex.: wuzapi.seudominio.com.br): " WUZAPI_DOMAIN
if [ -z "$WUZAPI_DOMAIN" ]; then err "Domínio é obrigatório."; exit 1; fi

ensure_repo "${PROJECT_DIR}/deploy/wuzapi" "https://github.com/leandrodes/wuzapi.git" "WuzAPI" || exit 1

# Tokens/endpoints no .env (não sobrescreve o que já existe).
ensure_env_var "$ENV_FILE" "WUZAPI_ADMIN_TOKEN" "$(gen_hex 32)"
ensure_env_var "$ENV_FILE" "WUZAPI_ENDPOINT" "$WUZAPI_WEB_URL"
ensure_env_var "$ENV_FILE" "WUZAPI_WEBHOOK_BASE_URL" "http://rails:3000"
ensure_compose_profile "$ENV_FILE" "wuzapi"

ensure_caddy_block "$WUZAPI_DOMAIN" "127.0.0.1:8080" "wuzapi" || true

cd "${PROJECT_DIR}/deploy"
say "Subindo container do WuzAPI..."
docker compose -f "$COMPOSE_FILE" up -d --build wuzapi

TOKEN="$(grep '^WUZAPI_ADMIN_TOKEN=' "$ENV_FILE" | head -1 | cut -d= -f2-)"
echo
say "WuzAPI instalado."
echo "  URL pública:        https://${WUZAPI_DOMAIN}"
echo "  Endpoint interno:   ${WUZAPI_WEB_URL}"
echo "  Admin token:        ${TOKEN}"
echo
say "Próximos passos (MANUAL):"
echo "  1) Entre no Omni-Channel Infinity como super admin."
echo "  2) Super Admin > Configurações > WhatsApp não oficial."
echo "  3) Preencha 'WUZAPI Endpoint' = ${WUZAPI_WEB_URL} (ou https://${WUZAPI_DOMAIN}) e o Admin Token acima."
echo "  4) Só então a caixa 'WhatsApp Não Oficial' ficará disponível para criação."
