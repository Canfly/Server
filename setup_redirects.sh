#!/bin/bash

# Проверяем, установлен ли pip
if ! command -v pip3 &> /dev/null; then
    echo "pip3 не найден. Устанавливаем..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        brew install python3
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        sudo apt update
        sudo apt install -y python3-pip
    else
        echo "Неподдерживаемая операционная система. Пожалуйста, установите python3-pip вручную."
        exit 1
    fi
fi

# Устанавливаем необходимые зависимости
echo "Устанавливаем необходимые Python пакеты..."
pip3 install python-dotenv requests

# Даем права на выполнение Python-скрипту
chmod +x setup_cloudflare_redirects.py

# Запускаем скрипт
echo "Запускаем скрипт настройки перенаправлений Cloudflare..."
python3 setup_cloudflare_redirects.py 