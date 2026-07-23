#!/bin/bash
set -e

CONFIG="/etc/update-server.conf"
LOG_FILE="/var/log/update-server.log"
BREW_USER=""
COMPOSE_FILES=""

if [ -f "$CONFIG" ]; then
    source "$CONFIG"
else
    echo "Конфиг $CONFIG не найден. Используются значения по умолчанию."
fi

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
if [ -n "$BREW_USER" ] && [ -x "$BREW_BIN" ]; then
    log "Обновление brew..."
    sudo -u "$BREW_USER" bash -c "
        export PATH=\"$(dirname $BREW_BIN):\$PATH\"
        brew update 2>&1
        brew upgrade 2>&1
        brew cleanup 2>&1
    " | while IFS= read -r line; do log "brew: $line"; done
else
    log "brew не настроен или не найден, пропускаем"
fi

# ---- 3. NPM глобальные пакеты ----
NPM_BIN="/home/linuxbrew/.linuxbrew/bin/npm"
if [ -n "$BREW_USER" ] && [ -x "$NPM_BIN" ]; then
    log "Обновление npm global..."
    sudo -u "$BREW_USER" bash -c "
        export PATH=\"$(dirname $NPM_BIN):\$PATH\"
        npm update -g 2>&1
    " | while IFS= read -r line; do log "npm: $line"; done
else
    log "npm не настроен или не найден, пропускаем"
fi

# ---- 4. Docker Compose контейнеры ----
if [ -n "$COMPOSE_FILES" ]; then
    for compose_file in $COMPOSE_FILES; do
        if [ ! -f "$compose_file" ]; then
            log "Файл $compose_file не найден, пропускаем"
            continue
        fi
        log "Обновление образов для $compose_file..."
        docker compose -f "$compose_file" pull 2>&1 | while IFS= read -r line; do log "docker-pull: $line"; done
        log "Перезапуск контейнеров для $compose_file..."
        docker compose -f "$compose_file" up -d --force-recreate 2>&1 | while IFS= read -r line; do log "docker-up: $line"; done
    done
else
    log "COMPOSE_FILES не задан, пропускаем обновление контейнеров"
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