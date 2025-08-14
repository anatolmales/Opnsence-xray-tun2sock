#!/bin/sh

# ==============================================================================
# Скрипт для автоматической установки и настройки xray и tun2socks на OPNsense
# Автор: Запилино через AI
# Версия: 1.0
# ==============================================================================

# Функция для вывода информационных сообщений
log_message() {
    echo "\n=> $1"
}

# Функция для проверки, запущен ли скрипт от имени root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "Ошибка: Этот скрипт необходимо запускать от имени root." >&2
        exit 1
    fi
}

# 1. Установка зависимостей
install_dependencies() {
    log_message "Установка необходимых пакетов: xray-core и unzip"
    pkg update -f > /dev/null 2>&1 # Обновляем список пакетов в фоне
    pkg install -y xray-core unzip # Устанавливаем xray и утилиту для распаковки zip
}

# 2. Настройка tun2socks
setup_tun2socks() {
    log_message "🧪 Настройка tun2socks..."

    # Создаем необходимые директории
    log_message "Создание директорий для tun2socks"
    mkdir -p /usr/local/etc/tun2socks/
    mkdir -p /usr/local/opnsense/service/conf/actions.d/
    mkdir -p /usr/local/etc/inc/plugins.inc.d/
    mkdir -p /usr/local/etc/rc.syshook.d/early/

    # 📂 Скачивание и установка бинарного файла tun2socks
    log_message "Скачивание и установка tun2socks"
    fetch -q -o /tmp/tun2socks.zip https://github.com/xjasonlyu/tun2socks/releases/download/v2.6.0/tun2socks-freebsd-amd64.zip
    unzip -p /tmp/tun2socks.zip tun2socks-freebsd-amd64 > /usr/local/etc/tun2socks/tun2socks
    chmod +x /usr/local/etc/tun2socks/tun2socks # Даем права на исполнение

    # ⚙️ Скачивание конфигурационных файлов
    log_message "Загрузка конфигурационных файлов для tun2socks"
    fetch -q -o /usr/local/etc/tun2socks/config.yaml https://github.com/anatolmales/Opnsence-xray-tun2sock/raw/refs/heads/main/tun2sock/config.yaml
    fetch -q -o /usr/local/etc/rc.d/tun2socks https://github.com/anatolmales/Opnsence-xray-tun2sock/raw/refs/heads/main/tun2sock/tun2socks
    fetch -q -o /usr/local/opnsense/service/conf/actions.d/actions_tun2socks.conf https://github.com/anatolmales/Opnsence-xray-tun2sock/raw/refs/heads/main/tun2sock/actions_tun2socks.conf
    fetch -q -o /usr/local/etc/inc/plugins.inc.d/tun2socks.inc https://github.com/anatolmales/Opnsence-xray-tun2sock/raw/refs/heads/main/tun2sock/tun2socks.inc
    fetch -q -o /usr/local/etc/rc.syshook.d/early/50-tun2socks https://github.com/anatolmales/Opnsence-xray-tun2sock/raw/refs/heads/main/tun2sock/50-tun2socks


    # 🧩 Настройка службы и автозапуска
    log_message "Настройка службы и автозапуска tun2socks"
    chmod +x /usr/local/etc/rc.d/tun2socks # Даем права на исполнение rc скрипту
    chmod +x /usr/local/etc/rc.syshook.d/early/50-tun2socks # Даем права на исполнение syshook
    echo 'tun2socks_enable="YES"' > /etc/rc.conf.d/tun2socks # Включаем автозапуск службы
}

# 3. Настройка Xray
setup_xray() {
    log_message "🔧 Настройка Xray..."

    # Создаем директории (на случай, если пакет их не создал)
    log_message "Создание директорий для Xray"
    mkdir -p /usr/local/etc/xray-core/

    # 📥 Скачивание конфигурационных файлов
    log_message "Загрузка конфигурационных файлов для Xray"
    fetch -q -o /usr/local/etc/rc.d/xray https://github.com/anatolmales/Opnsence-xray-tun2sock/raw/refs/heads/main/xray/xray
    fetch -q -o /usr/local/opnsense/service/conf/actions.d/actions_xray.conf https://github.com/anatolmales/Opnsence-xray-tun2sock/raw/refs/heads/main/xray/actions_xray.conf
    fetch -q -o /usr/local/etc/inc/plugins.inc.d/xray.inc https://github.com/anatolmales/Opnsence-xray-tun2sock/raw/refs/heads/main/xray/xray.inc
    fetch -q -o /usr/local/etc/rc.syshook.d/start/91-xray https://github.com/anatolmales/Opnsence-xray-tun2sock/raw/refs/heads/main/xray/91-xray
    fetch -q -o /usr/local/etc/xray-core/update-xray.sh https://github.com/anatolmales/Opnsence-xray-tun2sock/raw/refs/heads/main/xray-core/update-xray.sh

    # ⚙️ Настройка службы и автозапуска
    log_message "Настройка службы и автозапуска Xray"
    chmod +x /usr/local/etc/rc.d/xray # Даем права на исполнение rc скрипту
    chmod +x /usr/local/etc/rc.syshook.d/early/41-xray # Даем права на исполнение syshook
    chmod +x /usr/local/etc/xray-core/update-xray.sh # Даем права на исполнение скрипту обновления
    echo 'xray_enable="YES"' > /etc/rc.conf.d/xray # Включаем автозапуск службы
}

# 4. Финальная настройка и запуск
finalize_setup() {
    log_message "Завершение установки и применение настроек"

    # Перезагружаем плагины и службы OPNsense
    log_message "Перезагрузка плагинов и службы configd"
    pluginctl -s
    service configd restart

    # Запускаем службы
    log_message "Запуск служб tun2socks и xray"
    service tun2socks start
    service xray start

    # Обновляем базы GeoIP и GeoSite
    log_message "Первоначальное обновление баз GeoIP/GeoSite для Xray"
    /usr/local/etc/xray-core/update-xray.sh

    # Очистка
    log_message "Очистка временных файлов"
    rm /tmp/tun2socks.zip

    log_message "✅ Установка успешно завершена!"
    echo "Не забудьте настроить ваш файл /usr/local/etc/xray-core/config.json"
}

# ==============================================================================
# ОСНОВНАЯ ЛОГИКА СКРИПТА
# ==============================================================================
main() {
    check_root
    install_dependencies
    setup_tun2socks
    setup_xray
    finalize_setup
}

# Запуск основной функции
main
