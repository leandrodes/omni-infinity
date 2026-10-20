#!/bin/bash
# Instala o módulo Evolution API (WhatsApp não oficial via Baileys) de forma
# isolada, usando o mesmo Postgres/Redis do Omni-Channel.
#
# - Gera EVOLUTION_API_KEY (se ausente) e ajusta o .env
# - Adiciona o profile "evolution" no docker compose
# - Cria o banco "evolution" no Postgres
# - Sobe o container e grava Endpoint/API Key no Super Admin (InstallationConfig)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

if [ "$(id -u)" -ne 0 ]; then err "Execute como root (su -)."; exit 1; fi

PROJECT_DIR="$(omni_project_dir)"
ENV_FILE="${PROJECT_DIR}/deploy/.env"
COMPOSE_FILE="docker-compose.prod.yaml"
EVOLUTION_WEB_URL="http://evolution:8080"
EVOLUTION_LOCAL_URL="http://127.0.0.1:8081"

say "Instalando módulo Evolution API em ${PROJECT_DIR}"
if [ ! -f "$ENV_FILE" ]; then err ".env não encontrado em ${ENV_FILE}. Rode o install.sh primeiro."; exit 1; fi

ensure_env_var "$ENV_FILE" "EVOLUTION_API_KEY" "$(gen_hex 32)"
ensure_env_var "$ENV_FILE" "EVOLUTION_ENDPOINT" "$EVOLUTION_WEB_URL"
ensure_compose_profile "$ENV_FILE" "evolution"

cd "${PROJECT_DIR}/deploy"

say "Criando banco 'evolution' (se necessário)..."
if ! docker compose -f "$COMPOSE_FILE" exec -T postgres psql -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname='evolution'" 2>/dev/null | grep -q 1; then
  docker compose -f "$COMPOSE_FILE" exec -T postgres createdb -U postgres evolution || {
    err "Falha ao criar o banco 'evolution'. Verifique o container postgres."
    exit 1
  }
fi

say "Subindo container do Evolution API..."
docker compose -f "$COMPOSE_FILE" up -d evolution

KEY="$(grep '^EVOLUTION_API_KEY=' "$ENV_FILE" | head -1 | cut -d= -f2-)"
say "Aguardando o Evolution API responder..."
for _ in $(seq 1 60); do
  CODE="$(curl -s -o /dev/null -w '%{http_code}' -H "apikey: ${KEY}" "${EVOLUTION_LOCAL_URL}/instance/fetchInstances" || true)"
  if [ "$CODE" = "200" ] || [ "$CODE" = "401" ] || [ "$CODE" = "403" ]; then break; fi
  sleep 2
done

say "Gravando Endpoint/API Key no Super Admin..."
docker compose -f "$COMPOSE_FILE" exec -T rails bundle exec rails runner "
  {
    'EVOLUTION_ENDPOINT' => '${EVOLUTION_WEB_URL}',
    'EVOLUTION_API_KEY' => '${KEY}'
  }.each do |name, value|
    config = InstallationConfig.find_or_initialize_by(name: name)
    config.value = value
    config.save!
  end
  GlobalConfig.clear_cache
" || warn "Não foi possível gravar as configurações automaticamente. Preencha em Super Admin > Configurações > WhatsApp não oficial."

echo
say "Evolution API instalado."
echo "  Endpoint interno: ${EVOLUTION_WEB_URL}"
echo "  URL local:        ${EVOLUTION_LOCAL_URL}"
echo "  API Key:          ${KEY}"
echo
say "O canal 'WhatsApp API Não Oficial' já pode usar o provedor Evolution API (quando habilitado na conta)."
