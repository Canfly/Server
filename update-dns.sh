#!/bin/bash
# Скрипт для обновления DNS-записей в Cloudflare для домена fillin.moscow
# Использует Python-скрипт cloudflare-dns-update.py

# Проверяем, установлены ли необходимые зависимости
check_dependencies() {
    if ! command -v python3 &> /dev/null; then
        echo "Ошибка: python3 не установлен"
        exit 1
    fi
    
    # Проверяем, установлен ли pip и необходимые пакеты
    if ! python3 -c "import requests, dotenv" &> /dev/null; then
        echo "Устанавливаем необходимые Python пакеты..."
        pip3 install requests python-dotenv
    fi
}

# Выводим информацию о использовании
show_usage() {
    echo "Использование: $0 КОМАНДА [ОПЦИИ]"
    echo ""
    echo "Команды:"
    echo "  add-a СУБДОМЕН IP         - Добавить/обновить A запись для СУБДОМЕН -> IP"
    echo "  add-cname СУБДОМЕН ДОМЕН  - Добавить/обновить CNAME запись для СУБДОМЕН -> ДОМЕН"
    echo "  delete-a СУБДОМЕН         - Удалить A запись для СУБДОМЕН"
    echo "  delete-cname СУБДОМЕН     - Удалить CNAME запись для СУБДОМЕН"
    echo "  root IP                   - Обновить корневую A запись (@) на указанный IP"
    echo "  www ДОМЕН                 - Обновить www CNAME запись на указанный ДОМЕН"
    echo ""
    echo "Примеры:"
    echo "  $0 add-a api 192.168.1.1"
    echo "  $0 add-cname dev example.com"
    echo "  $0 delete-a old-api"
    echo "  $0 root 203.0.113.1"
    echo "  $0 www fillin.moscow"
    exit 1
}

# Проверяем аргументы
if [ $# -lt 1 ]; then
    show_usage
fi

# Проверяем зависимости
check_dependencies

# Обрабатываем команды
case "$1" in
    add-a)
        if [ $# -ne 3 ]; then
            echo "Ошибка: команда add-a требует два аргумента: СУБДОМЕН и IP"
            show_usage
        fi
        python3 cloudflare-dns-update.py --type A --name "$2" --content "$3"
        ;;
    add-cname)
        if [ $# -ne 3 ]; then
            echo "Ошибка: команда add-cname требует два аргумента: СУБДОМЕН и ДОМЕН"
            show_usage
        fi
        python3 cloudflare-dns-update.py --type CNAME --name "$2" --content "$3"
        ;;
    delete-a)
        if [ $# -ne 2 ]; then
            echo "Ошибка: команда delete-a требует один аргумент: СУБДОМЕН"
            show_usage
        fi
        python3 cloudflare-dns-update.py --delete --type A --name "$2"
        ;;
    delete-cname)
        if [ $# -ne 2 ]; then
            echo "Ошибка: команда delete-cname требует один аргумент: СУБДОМЕН"
            show_usage
        fi
        python3 cloudflare-dns-update.py --delete --type CNAME --name "$2"
        ;;
    root)
        if [ $# -ne 2 ]; then
            echo "Ошибка: команда root требует один аргумент: IP"
            show_usage
        fi
        python3 cloudflare-dns-update.py --type A --name "@" --content "$2"
        ;;
    www)
        if [ $# -ne 2 ]; then
            echo "Ошибка: команда www требует один аргумент: ДОМЕН"
            show_usage
        fi
        python3 cloudflare-dns-update.py --type CNAME --name "www" --content "$2"
        ;;
    *)
        echo "Неизвестная команда: $1"
        show_usage
        ;;
esac

# Выводим сообщение об успешном выполнении
echo "Операция успешно выполнена!"
exit 0 