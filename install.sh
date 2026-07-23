#!/bin/bash
set -e

SCRIPT_SRC="./update-server.sh"
SERVICE_SRC="./update-server.service"
TIMER_SRC="./update-server.timer"
SCRIPT_DST="/usr/local/bin/update-server.sh"
SERVICE_DST="/etc/systemd/system/update-server.service"
TIMER_DST="/etc/systemd/system/update-server.timer"

if [ ! -f "$SCRIPT_SRC" ]; then
    echo "Ошибка: $SCRIPT_SRC не найден. Запустите скрипт из корня репозитория."
    exit 1
fi

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

echo "Статус таймера:"
systemctl status update-server.timer --no-pager

echo ""
echo "Установка завершена. Таймер запускает обновление ежедневно."
echo "Для ручного запуска: sudo systemctl start update-server.service"
echo "Логи: /var/log/update-server.log"
