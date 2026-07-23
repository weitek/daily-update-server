# Daily Update Server

Скрипт для ежедневного автоматического обновления сервера: системных пакетов, Homebrew, npm, Docker-контейнеров (произвольные docker-compose), очистки неиспользуемых Docker-образов и опциональной перезагрузки.

## Состав

- `update-server.sh` — основной скрипт обновления
- `install.sh` — установка скрипта, systemd-таймера и создание конфигурации
- `update-server.service` — systemd unit для запуска
- `update-server.timer` — systemd timer для ежедневного запуска
- `/etc/update-server.conf` — конфигурация (создаётся при установке)

## Установка

```bash
sudo ./install.sh
```

В процессе установки скрипт запросит:
1. **Логин пользователя для brew/npm** — оставьте пустым, если brew не используется.
2. **Путь к директориям с docker-compose файлами** — можно указать несколько (по одному на строку). Пустая строка завершает ввод.

Все параметры сохраняются в `/etc/update-server.conf` и могут быть отредактированы вручную.

## Ручное управление конфигурацией

```ini
# /etc/update-server.conf
BREW_USER="username"          # пользователь для brew/npm (пусто = пропуск)
COMPOSE_DIRS="/opt/project1 /opt/project2"  # директории с docker-compose (через пробел)
```

## Использование

Таймер запускает обновление ежедневно в 03:00 (со случайной задержкой до 30 мин).
При необходимости перезагрузки сервер перезагружается через 1 минуту после завершения обновления.

```bash
# Ручной запуск
sudo systemctl start update-server.service

# Просмотр лога
tail -f /var/log/update-server.log

# Изменить конфиг
sudo nano /etc/update-server.conf
```

## Логи

Все действия логируются в `/var/log/update-server.log`.