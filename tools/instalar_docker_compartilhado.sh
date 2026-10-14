#!/bin/bash
# ==============================================================================
# AMANDA - Instalação e Garantia Oficial de Docker e Docker Compose
# Suporte: Ubuntu 20.04, 22.04, 24.04 (Noble), Debian 11, 12, 13 e derivados
# ==============================================================================

instalar_docker_compartilhado() {
  printf " >> Verificando e garantindo ambiente Docker e Docker Compose...\n"

  # 1. Liberar possíveis travas de pacotes no Ubuntu/Debian (unattended-upgrades, apt lock)
  local max_wait=20
  local wait_count=0
  while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
    if [ $wait_count -eq 0 ]; then
      printf " >> Aguardando liberação do gerenciador de pacotes apt/dpkg...\n"
    fi
    sleep 2
    wait_count=$((wait_count + 1))
    if [ $wait_count -ge $max_wait ]; then
      killall apt apt-get unattended-upgrades 2>/dev/null || true
      sleep 1
      rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/lib/apt/lists/lock 2>/dev/null || true
      dpkg --configure -a 2>/dev/null || true
      break
    fi
  done

  # 2. Instalar dependências essenciais
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y >/dev/null 2>&1 || true
  apt-get install -y ca-certificates curl gnupg lsb-release iptables git python3 >/dev/null 2>&1 || true

  # 3. Verificar/Instalar Docker Engine
  if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
    printf " >> Instalando Docker Engine...\n"
    if ! curl -fsSL https://get.docker.com | sh; then
      printf " >> Tentando instalar Docker via repositório da distribuição...\n"
      apt-get update -y
      apt-get install -y docker.io containerd
    fi
    systemctl daemon-reload 2>/dev/null || true
    systemctl enable docker 2>/dev/null || true
    systemctl restart docker 2>/dev/null || true

    local docker_wait=0
    while [ $docker_wait -lt 15 ]; do
      docker info >/dev/null 2>&1 && break
      sleep 1
      docker_wait=$((docker_wait + 1))
    done
  fi

  if ! docker info >/dev/null 2>&1; then
    systemctl start docker 2>/dev/null || service docker start 2>/dev/null || true
    sleep 2
  fi

  # 4. Verificar/Instalar Docker Compose (v2 plugin e CLI)
  if ! docker compose version >/dev/null 2>&1; then
    printf " >> Instalando Docker Compose Plugin via APT...\n"
    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y docker-compose-plugin docker-compose-v2 >/dev/null 2>&1 || true
  fi

  # Fallback: baixar binário oficial estático se APT não supriu
  if ! docker compose version >/dev/null 2>&1; then
    printf " >> Baixando binário oficial do Docker Compose Standalone...\n"
    local raw_arch
    raw_arch=$(dpkg --print-architecture 2>/dev/null || uname -m)
    local compose_arch="x86_64"
    case "$raw_arch" in
      aarch64|arm64) compose_arch="aarch64" ;;
      armv7l|armhf)  compose_arch="armv7" ;;
      *)             compose_arch="x86_64" ;;
    esac

    mkdir -p /usr/local/lib/docker/cli-plugins /usr/local/bin
    if curl -fsSL "https://github.com/docker/compose/releases/download/v2.29.7/docker-compose-linux-${compose_arch}" -o /usr/local/lib/docker/cli-plugins/docker-compose 2>/dev/null || \
       curl -fsSL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-${compose_arch}" -o /usr/local/lib/docker/cli-plugins/docker-compose 2>/dev/null; then
      chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
      ln -sf /usr/local/lib/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose
    fi
  fi

  # 5. Adicionar usuário deploy ao grupo docker
  if id -u deploy >/dev/null 2>&1; then
    usermod -aG docker deploy 2>/dev/null || true
  fi

  if docker info >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    printf " >> Docker e Docker Compose validados com sucesso!\n"
    return 0
  else
    printf " >> AVISO: Falha na validação do Docker/Compose.\n"
    return 1
  fi
}

verificar_docker_funcionando() {
  if ! command -v docker >/dev/null 2>&1; then
    return 1
  fi
  if ! docker info >/dev/null 2>&1; then
    systemctl start docker >/dev/null 2>&1 || true
    sleep 2
    docker info >/dev/null 2>&1 || return 1
  fi
  docker compose version >/dev/null 2>&1 || command -v docker-compose >/dev/null 2>&1
}

liberar_portas_e_servicos_host() {
  local target_db="${db_port:-5432}"
  local target_redis="${redis_port:-6379}"
  local target_pgb="${pgbouncer_port:-6432}"

  printf " >> Verificando portas configuradas (Postgres: %s, Redis: %s, PgBouncer: %s)...\n" "$target_db" "$target_redis" "$target_pgb"

  if [ "$target_db" = "5432" ] && (systemctl is-active --quiet postgresql 2>/dev/null || service postgresql status >/dev/null 2>&1); then
    printf " >> Desativando postgresql nativo para liberar porta 5432...\n"
    systemctl stop postgresql 2>/dev/null || service postgresql stop 2>/dev/null || true
    systemctl disable postgresql 2>/dev/null || true
  fi

  if [ "$target_redis" = "6379" ] && (systemctl is-active --quiet redis-server 2>/dev/null || service redis-server status >/dev/null 2>&1); then
    printf " >> Desativando redis-server nativo para liberar porta 6379...\n"
    systemctl stop redis-server 2>/dev/null || service redis-server stop 2>/dev/null || true
    systemctl disable redis-server 2>/dev/null || true
  fi

  local c
  for c in amanda_postgres amanda_redis amanda_pgbouncer amanda_backend amanda_frontend amanda_apioficial amanda_wuzapi amanda_campaign_dispatcher amanda_transcricao; do
    if docker ps -a --format '{{.Names}}' | grep -qw "$c"; then
      docker rm -f "$c" >/dev/null 2>&1 || true
    fi
  done

  testar_porta_tcp_ocupada() {
    local p="$1"
    if command -v ss >/dev/null 2>&1; then
      ss -tlpn 2>/dev/null | grep -qE "[:.]${p}\b" && return 0
    elif command -v netstat >/dev/null 2>&1; then
      netstat -tlpn 2>/dev/null | grep -qE "[:.]${p}\b" && return 0
    elif command -v lsof >/dev/null 2>&1; then
      lsof -iTCP:"$p" -sTCP:LISTEN >/dev/null 2>&1 && return 0
    fi
    (echo >/dev/tcp/127.0.0.1/"$p") 2>/dev/null && return 0
    return 1
  }

  local p
  for p in "$target_db" "$target_redis" "$target_pgb"; do
    if testar_porta_tcp_ocupada "$p"; then
      fuser -k "${p}/tcp" 2>/dev/null || true
      sleep 1
    fi
  done

  localizador_porta_livre() {
    local candidata="$1"
    while testar_porta_tcp_ocupada "$candidata"; do
      candidata=$((candidata + 1))
    done
    printf '%s\n' "$candidata"
  }

  PORT_DB_RESOLVIDA=$(localizador_porta_livre "$target_db")
  PORT_REDIS_RESOLVIDA=$(localizador_porta_livre "$target_redis")
  PORT_PGBOUNCER_RESOLVIDA=$(localizador_porta_livre "$target_pgb")
  db_port="$PORT_DB_RESOLVIDA"
  redis_port="$PORT_REDIS_RESOLVIDA"
  pgbouncer_port="$PORT_PGBOUNCER_RESOLVIDA"
  export PORT_DB_RESOLVIDA PORT_REDIS_RESOLVIDA PORT_PGBOUNCER_RESOLVIDA db_port redis_port pgbouncer_port
}

