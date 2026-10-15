#!/bin/bash
set -euo pipefail

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

check_dns() {
  local domain=$1
  local ip
  ip=$(curl -s --connect-timeout 5 https://api.ipify.org 2>/dev/null || curl -s --connect-timeout 5 https://ifconfig.me 2>/dev/null || true)
  if [ -z "$ip" ]; then
    warn "Não foi possível obter IP público. Pulando validação DNS para $domain"
    return 0
  fi
  local resolved
  resolved=$(getent hosts "$domain" 2>/dev/null | awk '{print $1}' | head -1)
  if [ -z "$resolved" ]; then
    resolved=$(nslookup "$domain" 2>/dev/null | grep -A1 "Name:" | grep "Address:" | awk '{print $NF}' | head -1)
  fi
  if [ "$resolved" = "$ip" ]; then
    say "✓ DNS $domain aponta para $ip"
    return 0
  else
    warn "DNS $domain não aponta para IP atual ($ip). Resolução atual: ${resolved:-desconhecido}"
    read -rp "Continuar mesmo assim? [s/N]: " cont
    if ! [[ "$cont" =~ ^[Ss]$ ]]; then
      err "Validação DNS falhou para $domain"
      exit 1
    fi
    return 0
  fi
}

gen_hex() {
  openssl rand -hex "$1" 2>/dev/null || head -c "$(( $1 * 2 ))" /dev/urandom | xxd -p -c 256 | head -c "$(( $1 * 2 ))" || true
}

check_prereqs
say "Instalador Omni-Infinity (Chatwoot personalizado)"
say "Projeto: $PROJECT_DIR"
echo

# Modo
read -rp "Selecione o modo de instalação: 
1) VPS direta (Caddy gera certificado Let's Encrypt)
2) Atrás de firewall/Sophos (certificado externo, Caddy proxy HTTP)

Opção [1/2]: " INSTALL_MODE
INSTALL_MODE=${INSTALL_MODE:-1}

# App domain
read -rp "Domínio principal do Chatwoot (ex.: app.seudominio.com.br): " APP_DOMAIN
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

say "Validando DNS dos domínios..."
check_dns "$APP_DOMAIN"
[ -n "$WUZAPI_DOMAIN" ] && check_dns "$WUZAPI_DOMAIN"
[ -n "$WACALLS_DOMAIN" ] && check_dns "$WACALLS_DOMAIN"

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
  read -rp "Configurar firewall UFW (22,80,443 [+5000])? [S/n]: " CFG_UFW
  CFG_UFW=${CFG_UFW:-S}
  read -rp "Instalar/configurar Fail2Ban (protecao contra brute force)? [S/n]: " CFG_FAIL2BAN
  CFG_FAIL2BAN=${CFG_FAIL2BAN:-S}
else
  read -rp "Configurar firewall UFW (22,80,443 [+5000])? [s/N]: " CFG_UFW
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
WACALLS_PUBLIC_IP="auto"

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
if [[ "$CFG_WACALLS" =~ ^[Ss]$ ]]; then
  {
    echo ""
    echo "# WaCalls"
    echo "WACALLS_API_KEY=${WACALLS_API_KEY}"
    echo "WACALLS_PUBLIC_IP=${WACALLS_PUBLIC_IP}"
  } >> .env
fi

# Caddyfile
TLS_DIRECTIVE=""
if [ "$INSTALL_MODE" = "1" ]; then
  # Modo 2: Caddy gera Let's Encrypt
  TLS_DIRECTIVE="  tls ${LE_EMAIL}"
else
  # Modo 1: Sophos termina TLS
  TLS_DIRECTIVE="  # TLS gerenciado externamente (firewall/Sophos)"
fi

WUZAPI_DOMAIN_BLOCK=""
if [[ "$CFG_WUZAPI" =~ ^[Ss]$ ]] && [ -n "$WUZAPI_DOMAIN" ]; then
  WUZAPI_DOMAIN_BLOCK="${WUZAPI_DOMAIN} {
${TLS_DIRECTIVE}

  encode gzip zstd
  reverse_proxy wuzapi:8080
}"
fi

WACALLS_DOMAIN_BLOCK=""
if [[ "$CFG_WACALLS" =~ ^[Ss]$ ]] && [ -n "$WACALLS_DOMAIN" ]; then
  WACALLS_DOMAIN_BLOCK="${WACALLS_DOMAIN} {
${TLS_DIRECTIVE}

  encode gzip zstd
  reverse_proxy wacalls:8080
}"
fi

export APP_DOMAIN TLS_DIRECTIVE WUZAPI_DOMAIN_BLOCK WACALLS_DOMAIN_BLOCK
envsubst < Caddyfile.template > Caddyfile

say "Arquivos gerados:"
ls -1 .env Caddyfile 2>/dev/null

echo
read -rp "Deseja atualizar docker-compose.prod.yaml para ativar serviços opcionais (WuzAPI/WaCalls)? [S/n]: " ACT_SVC
ACT_SVC=${ACT_SVC:-S}
if [[ "$ACT_SVC" =~ ^[Ss]$ ]]; then
  if [[ "$CFG_WUZAPI" =~ ^[Ss]$ ]]; then
    sed -i 's/^  # wuzapi:/  wuzapi:/' docker-compose.prod.yaml
    sed -i 's/^  #     image:/      image:/' docker-compose.prod.yaml
    sed -i 's/^  #     restart:/      restart:/' docker-compose.prod.yaml
    sed -i 's/^  #     volumes:/      volumes:/' docker-compose.prod.yaml
    sed -i 's/^  #     env_file:/      env_file:/' docker-compose.prod.yaml
    sed -i 's/^  #     ports:/      ports:/' docker-compose.prod.yaml
    sed -i 's/^  # wuzapi_data:/  wuzapi_data:/' docker-compose.prod.yaml
  fi
  if [[ "$CFG_WACALLS" =~ ^[Ss]$ ]]; then
    sed -i 's/^  # wacalls:/  wacalls:/' docker-compose.prod.yaml
    sed -i 's/^  #     image:/      image:/' docker-compose.prod.yaml
    sed -i 's/^  #     restart:/      restart:/' docker-compose.prod.yaml
    sed -i 's/^  #     ports:/      ports:/' docker-compose.prod.yaml
    sed -i 's/^  #     volumes:/      volumes:/' docker-compose.prod.yaml
    sed -i 's/^  #     env_file:/      env_file:/' docker-compose.prod.yaml
    sed -i 's/^  #     environment:/      environment:/' docker-compose.prod.yaml
    sed -i 's/^  #       - WACALLS_PUBLIC_IP=/        - WACALLS_PUBLIC_IP=/' docker-compose.prod.yaml
    sed -i 's/^  #       - WACALLS_UDP_PORT=/        - WACALLS_UDP_PORT=/' docker-compose.prod.yaml
    sed -i 's/^  #       - WACALLS_MAX_CALLS=/        - WACALLS_MAX_CALLS=/' docker-compose.prod.yaml
    sed -i 's/^  #       - WACALLS_API_KEY=/        - WACALLS_API_KEY=/' docker-compose.prod.yaml
    sed -i 's/^  # wacalls_data:/  wacalls_data:/' docker-compose.prod.yaml
  fi
  say "Serviços opcionais ativados no docker-compose.prod.yaml"
fi

echo
read -rp "Subir containers (docker compose up -d)? [S/n]: " UP
UP=${UP:-S}
if [[ "$UP" =~ ^[Ss]$ ]]; then
  say "Subindo containers em modo produção..."
  cd "$PROJECT_DIR/deploy"
  docker compose -f docker-compose.prod.yaml up -d
  say "Concluído. Aguarde ~60s para inicialização completa."
  echo
  say "URLs:"
  echo "  App: https://${APP_DOMAIN}"
  [ -n "$WUZAPI_DOMAIN" ] && echo "  WuzAPI: https://${WUZAPI_DOMAIN}"
  [ -n "$WACALLS_DOMAIN" ] && echo "  WaCalls: https://${WACALLS_DOMAIN}"
  echo
  say "Primeiro login (Chatwoot): john@acme.inc / Password1!"
else
  say "Instalação preparada. Para subir: cd ${PROJECT_DIR}/deploy && docker compose -f docker-compose.prod.yaml up -d"
fi

say "Finalizado."
