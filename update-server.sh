#!/bin/bash
set -e

LOG_FILE="/var/log/update-server.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "=== Начало обновления ==="

# ---- 1. Системные пакеты (apt) ----
log "Обновление системных пакетов..."
DEBIAN_FRONTEND=noninteractive apt update -qq 2>&1 | tee -a "$LOG_FILE"
DEBIAN_FRONTEND=noninteractive apt upgrade -y -qq 2>&1 | tee -a "$LOG_FILE"

REBOOT_REQUIRED=false
if [ -f /var/run/reboot-required ]; then
    REBOOT_REQUIRED=true
    log "Требуется перезагрузка (отмечено reboot-required)"
fi

# ---- 2. Brew ----
BREW_BIN="/home/linuxbrew/.linuxbrew/bin/brew"
if [ -x "$BREW_BIN" ]; then
    log "Обновление brew..."
    sudo -u weitek bash -c "
        export PATH=\"$(dirname $BREW_BIN):\$PATH\"
        brew update 2>&1
        brew upgrade 2>&1
        brew cleanup 2>&1
    " | while IFS= read -r line; do log "brew: $line"; done
else
    log "brew не найден, пропускаем"
fi

# ---- 3. NPM глобальные пакеты ----
NPM_BIN="/home/linuxbrew/.linuxbrew/bin/npm"
if [ -x "$NPM_BIN" ]; then
    log "Обновление npm global..."
    sudo -u weitek bash -c "
        export PATH=\"$(dirname $NPM_BIN):\$PATH\"
        npm update -g 2>&1
    " | while IFS= read -r line; do log "npm: $line"; done
else
    log "npm не найден, пропускаем"
fi

# ---- 4. Multica контейнеры ----
MULTICA_DIR="/home/weitek/2026-07-20-multica"
MULTICA_COMPOSE="$MULTICA_DIR/docker-compose.selfhost.yml"
if [ -f "$MULTICA_COMPOSE" ]; then
    log "Обновление Multica Docker образов..."
    docker compose -f "$MULTICA_COMPOSE" pull 2>&1 | while IFS= read -r line; do log "docker-pull: $line"; done
    log "Перезапуск Multica контейнеров..."
    docker compose -f "$MULTICA_COMPOSE" up -d --force-recreate 2>&1 | while IFS= read -r line; do log "docker-up: $line"; done
    log "Ожидание готовности backend..."
    for i in $(seq 1 30); do
        if curl -sf http://10.0.72.214:8080/health > /dev/null 2>&1; then
            log "Backend готов."
            break
        fi
        sleep 2
    done
    log "Перезапуск Multica daemon (все профили)..."
    systemctl daemon-reload 2>&1 | while IFS= read -r line; do log "systemd: $line"; done
    for svc in $(systemctl list-units --full --no-legend 'multica-daemon*' 2>/dev/null | awk '{print $1}'); do
        systemctl restart "$svc" 2>&1 | while IFS= read -r line; do log "systemd-restart: $line"; done
        log "  $svc перезапущен."
    done
else
    log "multica docker-compose не найден, пропускаем"
fi

# ---- 5. Очистка неиспользуемых Docker образов ----
log "Очистка неиспользуемых Docker образов..."
docker system prune -af 2>&1 | while IFS= read -r line; do log "docker: $line"; done || log "docker prune: ошибка (пропускаем)"

log "=== Обновление завершено ==="

# ---- 6. Перезагрузка ----
if [ "$REBOOT_REQUIRED" = true ]; then
    log "Перезагрузка сервера через 1 минуту..."
    shutdown -r +1 "Сервер перезагружается после системного обновления"
fi
