#!/bin/bash
set -euo pipefail

# Rodando via "wget | bash", o stdin é o pipe (fechado) e os `read` abortariam.
# Redireciona entrada de teclado para o terminal real (se existir).
if [ ! -t 0 ]; then
  if { exec 3</dev/tty; } 2>/dev/null; then
    exec 0<&3 3<&-
  fi
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

REQUIRED_DISK_GB=15
REQUIRED_RAM_GB=4
REQUIRED_CPU=2

say() { echo -e "\e[1;36m[Omni-Infinity]\e[0m $*"; }
warn() { echo -e "\e[1;33m[AVISO]\e[0m $*"; }
err() { echo -e "\e[1;31m[ERRO]\e[0m $*"; }

check_prereqs() {
  say "Verificando pré-requisitos..."
  DISK_AVAIL_GB=$(df -BG / | awk 'NR==2 {gsub("G","",$4); print $4}')
  if [ "$DISK_AVAIL_GB" -lt "$REQUIRED_DISK_GB" ]; then
    err "Espaço em disco insuficiente. Disponível: ${DISK_AVAIL_GB}GB, mínimo: ${REQUIRED_DISK_GB}GB"
    exit 1
  fi
  say "✓ Espaço em disco: ${DISK_AVAIL_GB}GB OK"
  RAM_TOTAL_GB=$(free -g | awk 'NR==2 {print $2}')
  if [ "$RAM_TOTAL_GB" -lt "$REQUIRED_RAM_GB" ]; then
    warn "Memória RAM baixa. Total: ${RAM_TOTAL_GB}GB, recomendado: ${REQUIRED_RAM_GB}GB"
  else
    say "✓ RAM: ${RAM_TOTAL_GB}GB OK"
  fi
  CPU_COUNT=$(nproc)
  if [ "$CPU_COUNT" -lt "$REQUIRED_CPU" ]; then
    warn "CPU baixa. Núcleos: ${CPU_COUNT}, recomendado: ${REQUIRED_CPU}"
  else
    say "✓ CPU: ${CPU_COUNT} núcleos OK"
  fi
  if ! command -v docker >/dev/null 2>&1; then
    err "Docker não encontrado. Instale o Docker antes de continuar."
    exit 1
  fi
  if ! docker compose version >/dev/null 2>&1 && ! docker-compose --version >/dev/null 2>&1; then
    err "Docker Compose não encontrado."
    exit 1
  fi
  say "✓ Docker e Docker Compose OK"
}

# Compara o DNS do domínio com o IP esperado (parâmetro 2).
# Se IP esperado vazio, apenas verifica se o domínio resolve.
check_dns() {
  local domain=$1
  local expected=${2:-}
  local resolved_all resolved
  resolved_all=$(getent ahostsv4 "$domain" 2>/dev/null | awk '{print $1}' | sort -u | paste -sd' ' - || true)
  if [ -z "$resolved_all" ]; then
    resolved_all=$(nslookup "$domain" 2>/dev/null | awk '/^Address: / {print $2}' | paste -sd' ' - || true)
  fi
  resolved=$(echo "$resolved_all" | awk '{print $1}')
  if [ -z "$resolved" ]; then
    warn "DNS $domain não resolve (nenhum registro A encontrado)"
    read -rp "Continuar mesmo assim? [s/N]: " cont
    if ! [[ "$cont" =~ ^[Ss]$ ]]; then
      err "Validação DNS falhou para $domain"
      exit 1
    fi
    return 0
  fi
  if [ -z "$expected" ]; then
    say "✓ DNS $domain resolve para: ${resolved_all}"
    return 0
  fi
  if echo " $resolved_all " | grep -q " $expected "; then
    say "✓ DNS $domain aponta para $expected"
    return 0
  fi
  warn "DNS $domain aponta para [$resolved_all], esperado: $expected"
  read -rp "Continuar mesmo assim? [s/N]: " cont
  if ! [[ "$cont" =~ ^[Ss]$ ]]; then
    err "Validação DNS falhou para $domain"
    exit 1
  fi
  return 0
}


setup_ufw() {
  if ! command -v ufw >/dev/null 2>&1; then
    warn "UFW não encontrado. Tentando instalar..."
    apt-get update -y && apt-get install -y ufw || true
  fi
  if ! command -v ufw >/dev/null 2>&1; then
    warn "Não foi possível instalar UFW. Pulando."
    return 0
  fi
  ufw default deny incoming >/dev/null 2>&1 || true
  ufw default allow outgoing >/dev/null 2>&1 || true
  ufw allow 22/tcp >/dev/null 2>&1 || true
  ufw allow 80/tcp >/dev/null 2>&1 || true
  ufw allow 443/tcp >/dev/null 2>&1 || true
  echo "y" | ufw enable >/dev/null 2>&1 || true
  say "✓ UFW configurado"
}

setup_fail2ban() {
  if ! command -v fail2ban-client >/dev/null 2>&1; then
    warn "Fail2Ban não encontrado. Tentando instalar..."
    apt-get update -y && apt-get install -y fail2ban >/dev/null 2>&1 || true
  fi
  if ! command -v fail2ban-client >/dev/null 2>&1; then
    warn "Não foi possível instalar Fail2Ban. Pulando."
    return 0
  fi
  mkdir -p /etc/fail2ban/jail.d
  mkdir -p /etc/fail2ban/filter.d
  mkdir -p ./logs/caddy
  touch ./logs/caddy/access.log
  if [ -f "$SCRIPT_DIR/fail2ban/filter.d/caddy-auth.conf" ]; then
    cp "$SCRIPT_DIR/fail2ban/filter.d/caddy-auth.conf" /etc/fail2ban/filter.d/caddy-auth.conf
    chmod 644 /etc/fail2ban/filter.d/caddy-auth.conf
  fi
  cat > /etc/fail2ban/jail.d/omni-infinity.conf << EOF
[sshd]
enabled = true
backend = systemd
journalmatch = _COMM=sshd
port = ssh
maxretry = 5
bantime = 1h
findtime = 10m

[caddy-auth]
enabled = true
filter = caddy-auth
port = http,https
logpath = ${PROJECT_DIR}/deploy/logs/caddy/*.log
maxretry = 5
bantime = 1h
findtime = 10m
EOF
  systemctl enable --now fail2ban >/dev/null 2>&1 || fail2ban-client start >/dev/null 2>&1 || true
  say "✓ Fail2Ban configurado"
}
gen_hex() {
  openssl rand -hex "$1" 2>/dev/null || head -c "$(( $1 * 2 ))" /dev/urandom | xxd -p -c 256 | head -c "$(( $1 * 2 ))" || true
}

check_prereqs
say "Instalador Omni-Channel Infinity"
say "Projeto: $PROJECT_DIR"
echo

# Modo
read -rp "Selecione o modo de instalação: 
1) VPS direta (Caddy gera certificado Let's Encrypt)
2) Atrás de um firewall WAF (Certificado externo, caddy proxy HTTP)

Opção [1/2]: " INSTALL_MODE
INSTALL_MODE=${INSTALL_MODE:-1}

# App domain
read -rp "Domínio principal do Omni-Channel Infinity (ex.: app.seudominio.com.br): " APP_DOMAIN
APP_DOMAIN=${APP_DOMAIN:-}

if [ -z "$APP_DOMAIN" ]; then
  err "Domínio do app é obrigatório."
  exit 1
fi

# WuzAPI
read -rp "Configurar WuzAPI (WhatsApp não-oficial)? [s/N]: " CFG_WUZAPI
CFG_WUZAPI=${CFG_WUZAPI:-N}
WUZAPI_DOMAIN=""
if [[ "$CFG_WUZAPI" =~ ^[Ss]$ ]]; then
  read -rp "Domínio do WuzAPI (ex.: wuzapi.seudominio.com.br): " WUZAPI_DOMAIN
fi

# WaCalls
read -rp "Configurar WaCalls (Chamadas de voz)? [s/N]: " CFG_WACALLS
CFG_WACALLS=${CFG_WACALLS:-N}
WACALLS_DOMAIN=""
if [[ "$CFG_WACALLS" =~ ^[Ss]$ ]]; then
  read -rp "Domínio do WaCalls (ex.: wacalls.seudominio.com.br): " WACALLS_DOMAIN
fi

# Portainer
read -rp "Configurar Portainer (painel de gerenciamento de containers)? [s/N]: " CFG_PORTAINER
CFG_PORTAINER=${CFG_PORTAINER:-N}
PORTAINER_DOMAIN=""
if [[ "$CFG_PORTAINER" =~ ^[Ss]$ ]]; then
  read -rp "Domínio do Portainer (ex.: painel.seudominio.com.br): " PORTAINER_DOMAIN
fi

# IP esperado para validar o DNS (varia por modo):
# - Modo 1 (VPS direta): sai o IP público da própria máquina (normalmente é o mesmo de entrada).
# - Modo 2 (atrás de firewall/NAT): o IP de saída (NAT) DIFERE do IP público de entrada do
#   firewall, então pedimos o IP público do firewall (aquele apontado no DNS).
EXPECTED_IP=""
if [ "$INSTALL_MODE" = "1" ]; then
  EXPECTED_IP=$(curl -s --connect-timeout 5 https://api.ipify.org 2>/dev/null || curl -s --connect-timeout 5 https://ifconfig.me 2>/dev/null || true)
else
  echo
  say "Modo 2 (atrás de firewall): informe o IP público do FIREWALL (entrada)."
  echo "  DNS desses domínios deve apontar para esse IP (ex.: 201.6.103.229)."
  read -rp "IP público do firewall (Enter = apenas verificar se resolve): " EXPECTED_IP
  EXPECTED_IP=${EXPECTED_IP:-}
fi

say "Validando DNS dos domínios..."
check_dns "$APP_DOMAIN" "$EXPECTED_IP"
[ -n "$WUZAPI_DOMAIN" ] && check_dns "$WUZAPI_DOMAIN" "$EXPECTED_IP"
[ -n "$WACALLS_DOMAIN" ] && check_dns "$WACALLS_DOMAIN" "$EXPECTED_IP"
[ -n "$PORTAINER_DOMAIN" ] && check_dns "$PORTAINER_DOMAIN" "$EXPECTED_IP"

# Email para Let's Encrypt (Modo 2 precisa)
LE_EMAIL=""
if [ "$INSTALL_MODE" = "1" ]; then
  read -rp "E-mail para alertas do Let's Encrypt (obrigatório no Modo 1): " LE_EMAIL
  if [ -z "$LE_EMAIL" ]; then
    warn "Usando no-reply@${APP_DOMAIN} como fallback"
    LE_EMAIL="no-reply@${APP_DOMAIN}"
  fi
fi

# Firewall e Fail2Ban
CFG_UFW=N
CFG_FAIL2BAN=N
if [ "$INSTALL_MODE" = "1" ]; then
  read -rp "Configurar firewall UFW (22,80,443)? [S/n]: " CFG_UFW
  CFG_UFW=${CFG_UFW:-S}
  read -rp "Instalar/configurar Fail2Ban (protecao contra brute force)? [S/n]: " CFG_FAIL2BAN
  CFG_FAIL2BAN=${CFG_FAIL2BAN:-S}
else
  read -rp "Configurar firewall UFW (22,80,443)? [s/N]: " CFG_UFW
  CFG_UFW=${CFG_UFW:-N}
  read -rp "Instalar/configurar Fail2Ban (protecao contra brute force)? [s/N]: " CFG_FAIL2BAN
  CFG_FAIL2BAN=${CFG_FAIL2BAN:-N}
fi

# Gera .env
cd "$PROJECT_DIR/deploy"
if [ -f .env ]; then
  read -rp "Arquivo .env já existe. Sobrescrever? [s/N]: " OVER
  if ! [[ "$OVER" =~ ^[Ss]$ ]]; then
    warn "Mantendo .env existente."
  else
    cp .env.prod.example .env
  fi
else
  cp .env.prod.example .env
fi

# Substitui variáveis
SECRET_KEY_BASE=$(gen_hex 64)
REDIS_PWD=$(gen_hex 32)
PG_PWD=$(gen_hex 32)
ARE_PKEY=$(gen_hex 16)
ARE_DKEY=$(gen_hex 16)
ARE_SALT=$(gen_hex 16)
WACALLS_API_KEY=$(gen_hex 32)
WUZAPI_ADMIN_TOKEN=$(gen_hex 32)

# sed replacements
sed -i "s|FRONTEND_URL=https://app.seudominio.com.br|FRONTEND_URL=https://${APP_DOMAIN}|" .env
sed -i "s|SECRET_KEY_BASE=GENERE_VIA_INSTALL|SECRET_KEY_BASE=${SECRET_KEY_BASE}|" .env
sed -i "s|ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=GENERE_VIA_INSTALL|ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=${ARE_PKEY}|" .env
sed -i "s|ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=GENERE_VIA_INSTALL|ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=${ARE_DKEY}|" .env
sed -i "s|ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=GENERE_VIA_INSTALL|ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=${ARE_SALT}|" .env
sed -i "s|REDIS_PASSWORD=GENERE_VIA_INSTALL|REDIS_PASSWORD=${REDIS_PWD}|" .env
sed -i "s|POSTGRES_PASSWORD=GENERE_VIA_INSTALL|POSTGRES_PASSWORD=${PG_PWD}|" .env
sed -i "s|SMTP_DOMAIN=app.seudominio.com.br|SMTP_DOMAIN=${APP_DOMAIN}|" .env
sed -i "s|MAILER_SENDER_EMAIL=Omni <no-reply@seudominio.com.br|MAILER_SENDER_EMAIL=Omni <no-reply@${APP_DOMAIN}|g" .env

# Adiciona variáveis opcionais
if [[ "$CFG_WUZAPI" =~ ^[Ss]$ ]]; then
  {
    echo ""
    echo "# WuzAPI"
    echo "WUZAPI_ADMIN_TOKEN=${WUZAPI_ADMIN_TOKEN}"
    echo "WUZAPI_ENDPOINT=http://wuzapi:8080"
  } >> .env
fi
if [[ "$CFG_WACALLS" =~ ^[Ss]$ ]]; then
  {
    echo ""
    echo "# WaCalls"
    echo "WACALLS_API_KEY=${WACALLS_API_KEY}"
    echo "WACALLS_MAX_CALLS=8"
  } >> .env
fi

# Profiles do Docker Compose ativam os serviços opcionais sem editar o compose.
# O update.sh respeita esta variável automaticamente.
COMPOSE_PROFILES_LIST=""
if [[ "$CFG_WUZAPI" =~ ^[Ss]$ ]]; then
  COMPOSE_PROFILES_LIST="${COMPOSE_PROFILES_LIST:+${COMPOSE_PROFILES_LIST},}wuzapi"
fi
if [[ "$CFG_WACALLS" =~ ^[Ss]$ ]]; then
  COMPOSE_PROFILES_LIST="${COMPOSE_PROFILES_LIST:+${COMPOSE_PROFILES_LIST},}wacalls"
fi
if [[ "$CFG_PORTAINER" =~ ^[Ss]$ ]]; then
  COMPOSE_PROFILES_LIST="${COMPOSE_PROFILES_LIST:+${COMPOSE_PROFILES_LIST},}portainer"
fi
if [ -n "$COMPOSE_PROFILES_LIST" ]; then
  {
    echo ""
    echo "# Serviços opcionais ativos (Docker Compose profiles)"
    echo "COMPOSE_PROFILES=${COMPOSE_PROFILES_LIST}"
  } >> .env
fi

# Caddyfile (esquema e global variam por modo)
# Modo 1 (VPS direta): Caddy faz TLS/Let's Encrypt na 443 (auto_https ligado).
# Modo 2 (atrás de um firewall WAF): o firewall faz TLS e encaminha HTTP:80 para a VM.
#   Nesse caso é OBRIGATÓRIO `auto_https off` e prefixo `http://` no endereço do site,
#   senão o Caddy tenta ACME/443 e não responde na 80 (o firewall devolve 503).
SCHEME=""
GLOBAL_OPTIONS=""
if [ "$INSTALL_MODE" = "1" ]; then
  TLS_DIRECTIVE="  tls ${LE_EMAIL}"
else
  SCHEME="http://"
  GLOBAL_OPTIONS=$'{\n  auto_https off\n}'
  TLS_DIRECTIVE="  # TLS gerenciado externamente (firewall WAF)"
fi

WUZAPI_DOMAIN_BLOCK=""
if [[ "$CFG_WUZAPI" =~ ^[Ss]$ ]] && [ -n "$WUZAPI_DOMAIN" ]; then
  WUZAPI_DOMAIN_BLOCK="${SCHEME}${WUZAPI_DOMAIN} {
${TLS_DIRECTIVE}

  encode gzip zstd
  reverse_proxy wuzapi:8080
}"
fi

WACALLS_DOMAIN_BLOCK=""
if [[ "$CFG_WACALLS" =~ ^[Ss]$ ]] && [ -n "$WACALLS_DOMAIN" ]; then
  WACALLS_DOMAIN_BLOCK="${SCHEME}${WACALLS_DOMAIN} {
${TLS_DIRECTIVE}

  encode gzip zstd
  reverse_proxy wacalls:8080
}"
fi

PORTAINER_DOMAIN_BLOCK=""
if [[ "$CFG_PORTAINER" =~ ^[Ss]$ ]] && [ -n "$PORTAINER_DOMAIN" ]; then
  PORTAINER_DOMAIN_BLOCK="${SCHEME}${PORTAINER_DOMAIN} {
${TLS_DIRECTIVE}

  encode gzip zstd
  reverse_proxy portainer:9000
}"
fi

export APP_DOMAIN TLS_DIRECTIVE WUZAPI_DOMAIN_BLOCK WACALLS_DOMAIN_BLOCK PORTAINER_DOMAIN_BLOCK SCHEME GLOBAL_OPTIONS
envsubst < Caddyfile.template > Caddyfile

say "Arquivos gerados:"
ls -1 .env Caddyfile 2>/dev/null

# Clona forks públicos para build local (se ainda não existirem)
mkdir -p "$PROJECT_DIR/deploy"
if [[ "$CFG_WUZAPI" =~ ^[Ss]$ ]] && [ ! -d "$PROJECT_DIR/deploy/wuzapi/.git" ]; then
  say "Clonando WuzAPI (fork público)..."
  git clone --depth 1 https://github.com/leandrodes/wuzapi.git "$PROJECT_DIR/deploy/wuzapi" || warn "Não foi possível clonar leandrodes/wuzapi"
fi
if [[ "$CFG_WACALLS" =~ ^[Ss]$ ]] && [ ! -d "$PROJECT_DIR/deploy/wacalls/.git" ]; then
  say "Clonando WaCalls (fork público)..."
  git clone --depth 1 https://github.com/leandrodes/wacalls.git "$PROJECT_DIR/deploy/wacalls" || warn "Não foi possível clonar leandrodes/wacalls"
fi

echo
read -rp "Subir containers (docker compose up -d)? [S/n]: " UP
UP=${UP:-S}
if [[ "$CFG_UFW" =~ ^[Ss]$ ]]; then
  setup_ufw
fi
if [[ "$CFG_FAIL2BAN" =~ ^[Ss]$ ]]; then
  setup_fail2ban
fi

if [[ "$UP" =~ ^[Ss]$ ]]; then
  say "Subindo containers em modo produção..."
  cd "$PROJECT_DIR/deploy"
  # 0) Baixa a imagem customizada (GHCR)
  say "Baixando imagem do Omni-Infinity (ghcr.io/leandrodes/omni-infinity)..."
  if ! docker compose -f docker-compose.prod.yaml pull rails sidekiq; then
    err "Falha ao baixar a imagem. Verifique se o pacote 'omni-infinity' está PÚBLICO em GitHub > Packages."
    exit 1
  fi
  # 1) Banco e cache primeiro (o app depende deles)
  docker compose -f docker-compose.prod.yaml up -d postgres redis
  say "Aguardando o Postgres ficar pronto..."
  for _ in $(seq 1 30); do
    if docker compose -f docker-compose.prod.yaml exec -T postgres pg_isready -U postgres >/dev/null 2>&1; then
      break
    fi
    sleep 2
  done
  # 2) Migrations + seed. SEM isso o Rails/Sidekiq entram em crash-loop
  #    ("relation installation_configs does not exist") e o proxy devolve 502.
  say "Preparando banco de dados (migrations)... isso pode levar alguns minutos."
  if ! docker compose -f docker-compose.prod.yaml run --rm -T rails bundle exec rails db:chatwoot_prepare </dev/null; then
    err "Falha ao preparar o banco. Verifique os logs acima e o arquivo .env."
    exit 1
  fi
  say "✓ Banco preparado"
  # 2b) Aplica a identidade visual "Omni-Channel Infinity" (marca, logo, links).
  say "Aplicando identidade visual (Omni-Channel Infinity)..."
  docker compose -f docker-compose.prod.yaml run --rm -T rails bundle exec rails omni:rebrand </dev/null \
    || warn "Não foi possível aplicar a identidade visual (seguindo)."
  # 3) App e proxy
  docker compose -f docker-compose.prod.yaml up -d rails sidekiq caddy
  # Serviços opcionais: falha em um não derruba o restante
  if [[ "$CFG_WUZAPI" =~ ^[Ss]$ ]]; then
    if docker compose -f docker-compose.prod.yaml up -d wuzapi; then
      say "✓ WuzAPI ativo"
    else
      warn "Falha ao subir WuzAPI (verifique a imagem/porta). O restante segue funcionando."
    fi
  fi
  if [[ "$CFG_WACALLS" =~ ^[Ss]$ ]]; then
    if docker compose -f docker-compose.prod.yaml up -d wacalls; then
      say "✓ WaCalls ativo"
    else
      warn "Falha ao subir WaCalls. Verifique build e logs: docker compose -f docker-compose.prod.yaml logs --tail=40 wacalls"
    fi
  fi
  if [[ "$CFG_PORTAINER" =~ ^[Ss]$ ]]; then
    if docker compose -f docker-compose.prod.yaml up -d portainer; then
      say "✓ Portainer ativo"
    else
      warn "Falha ao subir Portainer (verifique a imagem/porta). O restante segue funcionando."
    fi
  fi
  say "Concluído. Aguarde ~60s para inicialização completa."
  echo
  say "URLs:"
  echo "  App: https://${APP_DOMAIN}"
  [ -n "$WUZAPI_DOMAIN" ] && echo "  WuzAPI: https://${WUZAPI_DOMAIN}"
  [ -n "$WACALLS_DOMAIN" ] && echo "  WaCalls: https://${WACALLS_DOMAIN}"
  [ -n "$PORTAINER_DOMAIN" ] && echo "  Portainer: https://${PORTAINER_DOMAIN}"
  echo
  say "Credenciais geradas (GUARDE ESTES TOKENS! Também estão em ${PROJECT_DIR}/deploy/.env):"
  [[ "$CFG_WUZAPI" =~ ^[Ss]$ ]] && echo "  WuzAPI  (token admin): ${WUZAPI_ADMIN_TOKEN}"
  [[ "$CFG_WACALLS" =~ ^[Ss]$ ]] && echo "  WaCalls (X-API-Key):  ${WACALLS_API_KEY}"
  echo
  say "Verifique o estado com: docker compose -f docker-compose.prod.yaml ps"
  say "Primeiro acesso ao Omni-Channel Infinity: crie a conta de administrador em https://${APP_DOMAIN}"
else
  say "Instalação preparada. Para subir: cd ${PROJECT_DIR}/deploy && docker compose -f docker-compose.prod.yaml up -d"
fi

say "Finalizado."
