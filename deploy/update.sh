#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

say() { echo -e "\e[1;36m[Omni-Infinity-Update]\e[0m $*"; }
warn() { echo -e "\e[1;33m[AVISO]\e[0m $*"; }

say "Atualizando Omni-Infinity (Chatwoot personalizado)"
cd "$PROJECT_DIR"
git pull origin main
cd "$PROJECT_DIR/deploy"

# Forks locais (WuzAPI/WaCalls) são buildados na própria máquina: atualiza os clones.
for d in wuzapi wacalls; do
  if [ -d "$d/.git" ]; then
    say "Atualizando clone local: $d"
    git -C "$d" pull --ff-only || warn "Não foi possível atualizar $d (seguindo)."
  fi
done

say "Baixando imagens (Chatwoot do GHCR)..."
docker compose -f docker-compose.prod.yaml pull rails sidekiq

say "Recriando containers (rebuild dos build locais: wuzapi/wacalls)..."
docker compose -f docker-compose.prod.yaml up -d --build

say "Aplicando migrations do banco (db:chatwoot_prepare)..."
docker compose -f docker-compose.prod.yaml run --rm rails bundle exec rails db:chatwoot_prepare

say "Concluído. Containers atualizados."
docker compose -f docker-compose.prod.yaml ps
