#!/bin/bash
# Funções compartilhadas pelos scripts modulares do Omni-Channel Infinity.
# Uso: source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

omni_project_dir() {
  if [ -n "${OMNI_PROJECT_DIR:-}" ] && [ -d "$OMNI_PROJECT_DIR/deploy" ]; then
    echo "$OMNI_PROJECT_DIR"; return 0
  fi
  if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    local d
    d="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    if [ -d "$d/deploy" ]; then echo "$d"; return 0; fi
  fi
  echo "/opt/omni-infinity"
}

say()  { echo -e "\e[1;36m[Omni]\e[0m $*"; }
warn() { echo -e "\e[1;33m[AVISO]\e[0m $*"; }
err()  { echo -e "\e[1;31m[ERRO]\e[0m $*"; }

gen_hex() { openssl rand -hex "$1" 2>/dev/null || head -c "$(( $1 * 2 ))" /dev/urandom | xxd -p -c 256 | head -c "$(( $1 * 2 ))"; }

# Garante KEY=VALOR no .env (não sobrescreve valor existente).
ensure_env_var() {
  local file="$1" key="$2" value="$3"
  if ! grep -q "^${key}=" "$file" 2>/dev/null; then
    printf '\n%s=%s\n' "$key" "$value" >> "$file"
    say "Variável ${key} adicionada ao .env"
  fi
}

# Adiciona um profile ao COMPOSE_PROFILES (cria a linha se não existir).
ensure_compose_profile() {
  local file="$1" profile="$2" current
  if grep -q "^COMPOSE_PROFILES=" "$file" 2>/dev/null; then
    current="$(grep "^COMPOSE_PROFILES=" "$file" | head -1 | cut -d= -f2-)"
    if ! echo ",$current," | grep -q ",${profile},"; then
      sed -i "s|^COMPOSE_PROFILES=.*|COMPOSE_PROFILES=${current:+$current,}${profile}|" "$file"
      say "Profile '${profile}' adicionado ao COMPOSE_PROFILES"
    fi
  else
    printf '\nCOMPOSE_PROFILES=%s\n' "$profile" >> "$file"
    say "COMPOSE_PROFILES=${profile} definido no .env"
  fi
}

# Headers do Caddy. Em Modo 2 (auto_https off) os blocos precisam do prefixo http://.
caddy_scheme() {
  local caddyfile="$1"
  if grep -q "auto_https off" "$caddyfile" 2>/dev/null; then
    echo "http://"
  else
    echo ""
  fi
}

# Adiciona (se ausente) um bloco de domínio no Caddyfile do host e recarrega.
# Args: <domínio> <upstream host:porta> <tag-do-log>
ensure_caddy_block() {
  local domain="$1" upstream="$2" tag="$3"
  local caddyfile="/etc/caddy/Caddyfile"
  if [ ! -f "$caddyfile" ]; then
    warn "Caddyfile não encontrado em ${caddyfile}; adicione o bloco manualmente."
    return 1
  fi
  if grep -q "reverse_proxy ${upstream}" "$caddyfile" 2>/dev/null; then
    say "Bloco Caddy para ${domain} (${upstream}) já existe."
    return 0
  fi
  local scheme
  scheme="$(caddy_scheme "$caddyfile")"
  {
    echo ""
    echo "${scheme}${domain} {"
    echo "  encode gzip zstd"
    echo "  log {"
    echo "    output file /var/log/caddy/${tag}-access.log"
    echo "    format json"
    echo "  }"
    echo "  reverse_proxy ${upstream}"
    echo "}"
  } >> "$caddyfile"
  say "Bloco Caddy adicionado: ${domain} -> ${upstream}"
  reload_caddy
}

reload_caddy() {
  if ! command -v caddy >/dev/null 2>&1; then
    warn "Caddy não encontrado no host; não foi possível recarregar."
    return 0
  fi
  mkdir -p /var/log/caddy
  touch /var/log/caddy/access.log
  chown -R caddy:caddy /var/log/caddy 2>/dev/null || true
  if caddy validate --config /etc/caddy/Caddyfile >/dev/null 2>&1; then
    systemctl reload caddy 2>/dev/null || systemctl restart caddy 2>/dev/null || true
    say "Caddy (host) recarregado."
  else
    err "Caddyfile inválido após alteração. Revise /etc/caddy/Caddyfile."
    return 1
  fi
}

# Clona (depth 1) o fork público do módulo se ainda não existir.
ensure_repo() {
  local dir="$1" url="$2" name="$3"
  if [ ! -d "${dir}/.git" ]; then
    say "Clonando ${name} (fork público)..."
    git clone --depth 1 "$url" "$dir" || { err "Falha ao clonar ${url}"; return 1; }
  fi
  return 0
}
