#!/bin/bash
# Instala o módulo de Transcrição de Áudio (Whisper) de forma isolada.
# - Ativa o profile "whisper" no docker compose
# - Sobe o container Whisper (http://whisper:9000, interno)
# - Grava TRANSCRIPTION_ENDPOINT/MODEL/LANGUAGE no Omni-Channel (InstallationConfig)
#
# Depois disso a transcrição fica disponível no Super Admin > Configurações >
# Transcrição e os áudios recebidos (WhatsApp oficial e não oficial) passam a ser
# transcritos automaticamente.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

if [ "$(id -u)" -ne 0 ]; then err "Execute como root (su -)."; exit 1; fi

PROJECT_DIR="$(omni_project_dir)"
ENV_FILE="${PROJECT_DIR}/deploy/.env"
COMPOSE_FILE="docker-compose.prod.yaml"
TRANSCRIPTION_INTERNAL_URL="http://whisper:9000"

say "Instalando módulo de Transcrição (Whisper) em ${PROJECT_DIR}"
if [ ! -f "$ENV_FILE" ]; then err ".env não encontrado em ${ENV_FILE}. Rode o install.sh primeiro."; exit 1; fi

read -rp "Modelo do Whisper [tiny|base|small|medium|large-v3] (padrão: small): " WHISPER_MODEL
WHISPER_MODEL="${WHISPER_MODEL:-small}"

read -rp "Idioma da transcrição (ex.: pt, en; vazio = detecção automática) [padrão: pt]: " WHISPER_LANG
WHISPER_LANG="${WHISPER_LANG:-pt}"

ensure_env_var "$ENV_FILE" "WHISPER_ENGINE" "faster_whisper"
ensure_env_var "$ENV_FILE" "WHISPER_MODEL" "$WHISPER_MODEL"
ensure_compose_profile "$ENV_FILE" "whisper"

cd "${PROJECT_DIR}/deploy"
say "Baixando imagem e subindo o container do Whisper (a 1ª execução baixa o modelo, pode demorar)..."
docker compose -f "$COMPOSE_FILE" up -d whisper

say "Aguardando o endpoint de transcrição responder em 127.0.0.1:9005 ..."
READY=0
for _ in $(seq 1 60); do
  if curl -sf "http://127.0.0.1:9005/docs" >/dev/null 2>&1; then READY=1; break; fi
  sleep 3
done
[ "$READY" -eq 1 ] && say "Whisper respondendo." || warn "Whisper ainda não respondeu; o modelo pode estar sendo baixado em segundo plano."

say "Gravando a configuração de transcrição no Omni-Channel..."
RC_FILE="$(mktemp)"
cat > "$RC_FILE" <<RB
configs = {
  'TRANSCRIPTION_ENDPOINT' => '${TRANSCRIPTION_INTERNAL_URL}',
  'TRANSCRIPTION_MODEL' => '${WHISPER_MODEL}',
  'TRANSCRIPTION_LANGUAGE' => '${WHISPER_LANG}'
}
configs.each do |name, value|
  c = InstallationConfig.where(name: name).first_or_initialize
  c.value = value
  c.locked = false
  c.save!
  puts "#{name}=#{c.value.inspect}"
end
puts 'transcription config ok'
RB
if docker compose -f "$COMPOSE_FILE" exec -T rails bundle exec rails runner - < "$RC_FILE"; then
  say "Configuração gravada."
else
  warn "Não foi possível gravar automaticamente. Preencha em Super Admin > Configurações > Transcrição."
fi
rm -f "$RC_FILE"

echo
say "Transcrição (Whisper) instalada."
echo "  Endpoint interno:   ${TRANSCRIPTION_INTERNAL_URL}"
echo "  Endpoint de debug:  http://127.0.0.1:9005"
echo "  Modelo:             ${WHISPER_MODEL}"
echo "  Idioma:             ${WHISPER_LANG:-auto}"
echo
say "Os áudios recebidos passam a ser transcritos automaticamente."
echo "  - Para desligar por conta: Configurações (agente) > Transcrição de Áudio."
echo "  - Para ajustar o endpoint/modelo: Super Admin > Configurações > Transcrição."
