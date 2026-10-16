#!/bin/bash
set -euo pipefail

# Atualização MANUAL do Omni-Channel Infinity.
#
# Comando recomendado (seguro; NÃO use `curl ... | bash`, pois o `docker compose run`
# consumiria o restante do script a partir do stdin e abortaria a atualização):
#
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/leandrodes/omni-infinity/main/deploy/update.sh)"
#
# Como o script pode ser executado de fora da pasta, localizamos a instalação no
# caminho padrão /opt/omni-infinity.
DEFAULT_DIR="/opt/omni-infinity"
PROJECT_DIR="$DEFAULT_DIR"
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  _cand="$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")"
  [ -d "$_cand/deploy" ] && PROJECT_DIR="$_cand"
fi

say() { echo -e "\e[1;36m[Omni-Channel Infinity - Update]\e[0m $*"; }
warn() { echo -e "\e[1;33m[AVISO]\e[0m $*"; }
err() { echo -e "\e[1;31m[ERRO]\e[0m $*"; }

if [ ! -d "$PROJECT_DIR/deploy" ]; then
  err "Instalação não encontrada em $PROJECT_DIR (esperado: $PROJECT_DIR/deploy)."
  exit 1
fi

say "Atualizando Omni-Channel Infinity em $PROJECT_DIR"
cd "$PROJECT_DIR"
# Versões antigas do instalador editavam o compose e quebravam o `git pull`.
# Descarta alterações locais em arquivos rastreados do deploy (não toca em .env/Caddyfile/wuzapi/wacalls).
git checkout -- deploy/ 2>/dev/null || true
git pull origin main
cd "$PROJECT_DIR/deploy"

# Migra instalações antigas: os serviços opcionais agora usam Docker Compose
# profiles. Se o .env ainda não tem COMPOSE_PROFILES, detecta o que está rodando
# e grava, para não derrubar wuzapi/wacalls/portainer no upgrade.
if ! grep -q '^COMPOSE_PROFILES=' .env 2>/dev/null; then
  _profiles=""
  for _svc in wuzapi wacalls portainer; do
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "$_svc"; then
      _profiles="${_profiles:+$_profiles,}$_svc"
    fi
  done
  if [ -n "$_profiles" ]; then
    echo "COMPOSE_PROFILES=$_profiles" >> .env
    say "COMPOSE_PROFILES gravado no .env: $_profiles"
  fi
fi

# Forks locais (WuzAPI/WaCalls) são buildados na própria máquina: atualiza os clones.
for d in wuzapi wacalls; do
  if [ -d "$d/.git" ]; then
    say "Atualizando clone local: $d"
    git -C "$d" pull --ff-only || warn "Não foi possível atualizar $d (seguindo)."
  fi
done

say "Baixando imagens (GHCR)..."
docker compose -f docker-compose.prod.yaml pull rails sidekiq

say "Recriando containers (rebuild dos build locais: wuzapi/wacalls)..."
docker compose -f docker-compose.prod.yaml up -d --build

say "Aplicando migrations do banco (db:chatwoot_prepare)..."
docker compose -f docker-compose.prod.yaml run --rm -T rails bundle exec rails db:chatwoot_prepare </dev/null

say "Aplicando identidade visual (Omni-Channel Infinity)..."
docker compose -f docker-compose.prod.yaml run --rm -T rails bundle exec rails omni:rebrand </dev/null \
  || warn "Não foi possível aplicar a identidade visual (seguindo)."

say "Concluído. Containers atualizados."
docker compose -f docker-compose.prod.yaml ps
