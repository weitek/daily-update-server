#!/bin/bash
set -e

SCRIPT_SRC="./update-server.sh"
SERVICE_SRC="./update-server.service"
TIMER_SRC="./update-server.timer"
SCRIPT_DST="/usr/local/bin/update-server.sh"
SERVICE_DST="/etc/systemd/system/update-server.service"
TIMER_DST="/etc/systemd/system/update-server.timer"
CONFIG_DST="/etc/update-server.conf"

if [ ! -f "$SCRIPT_SRC" ]; then
    echo "Ошибка: $SCRIPT_SRC не найден. Запустите скрипт из корня репозитория."
    exit 1
fi

# ---- Сбор конфигурации ----

echo ""
echo "=== Настройка update-server ==="
echo ""

read -r -p "Логин пользователя для brew/npm (оставьте пустым, если brew не используется): " BREW_USER

COMPOSE_DIRS=()
echo "Введите пути к директориям с docker-compose файлами."
echo "Каждый путь на отдельной строке. Пустая строка — завершить ввод."
while true; do
    read -r -p "  Путь: " dir
    if [ -z "$dir" ]; then
        break
    fi
    dir="${dir/#\~/$HOME}"
    if [ -d "$dir" ]; then
        COMPOSE_DIRS+=("$dir")
    else
        echo "  Предупреждение: директория '$dir' не существует, но будет добавлена."
        COMPOSE_DIRS+=("$dir")
    fi
done

# ---- Создание конфига ----

echo ""
echo "Создание $CONFIG_DST..."

cat > "$CONFIG_DST" << EOF
# Конфигурация update-server
# Создан автоматически при установке $(date '+%Y-%m-%d %H:%M:%S')

# Пользователь для brew/npm (оставьте пустым для пропуска)
BREW_USER="${BREW_USER}"

# Директории c docker-compose файлами (через пробел)
COMPOSE_DIRS="${COMPOSE_DIRS[*]}"
EOF

chmod 644 "$CONFIG_DST"
echo "Конфиг создан."

# ---- Установка файлов ----

echo ""
echo "Копирование скрипта..."
install -m 755 "$SCRIPT_SRC" "$SCRIPT_DST"

echo "Копирование systemd unit..."
install -m 644 "$SERVICE_SRC" "$SERVICE_DST"
install -m 644 "$TIMER_SRC" "$TIMER_DST"

echo "Перезагрузка systemd..."
systemctl daemon-reload

echo "Включение и запуск таймера..."
systemctl enable update-server.timer
systemctl start update-server.timer

echo ""
echo "Статус таймера:"
systemctl status update-server.timer --no-pager

echo ""
echo "Установка завершена. Таймер запускает обновление ежедневно."
echo "Для ручного запуска: sudo systemctl start update-server.service"
echo "Логи: /var/log/update-server.log"
echo "Конфиг: $CONFIG_DST"