#!/usr/bin/env bash

# canfly | культура твоего сознания» 

# --------------------- Вспомогательные функции ---------------------

# Цветной вывод для удобства чтения
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Директория для логов и конфигурации
LOG_DIR="$HOME/.railway-canfly-logs"
CONFIG_DIR="$HOME/.railway-canfly-config"
LOG_FILE="$LOG_DIR/deploy-$(date +%Y%m%d-%H%M%S).log"

# Создаем директории
mkdir -p "$LOG_DIR"
mkdir -p "$CONFIG_DIR"

# Функция для логирования
log() {
  local level="$1"
  local message="$2"
  local color=""
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  
  case "$level" in
    "INFO") color="$BLUE" ;;
    "SUCCESS") color="$GREEN" ;;
    "WARNING") color="$YELLOW" ;;
    "ERROR") color="$RED" ;;
    *) color="$NC" ;;
  esac
  
  echo -e "${color}[$level]${NC} $message"
  echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

info() { log "INFO" "$1"; }
success() { log "SUCCESS" "$1"; }
warning() { log "WARNING" "$1"; }
error() { log "ERROR" "$1"; exit 1; }

# Проверка наличия необходимых команд
check_command() {
  if ! command -v $1 &> /dev/null; then
    error "Команда $1 не найдена. Пожалуйста, установите $1 и попробуйте снова."
  fi
}

# --------------------- Проверка предварительных условий ---------------------

info "Начинаем процесс развертывания на Railway..."
info "Логи будут сохранены в $LOG_FILE"

# Проверяем наличие необходимых команд
check_command curl
check_command railway
check_command jq
check_command python3
check_command pip3

# Проверяем авторизацию в Railway
railway whoami
if [ $? -ne 0 ]; then
  warning "Вы не авторизованы в Railway CLI. Запускаем процесс авторизации..."
  railway login
  if [ $? -ne 0 ]; then
    error "Не удалось авторизоваться в Railway. Пожалуйста, попробуйте вручную командой 'railway login'."
  fi
fi

info "Проверка авторизации в Railway успешна."

# --------------------- Конфигурация проекта ---------------------

# Создаем или загружаем файл конфигурации
CONFIG_FILE="$CONFIG_DIR/railway-config.json"

if [ ! -f "$CONFIG_FILE" ]; then
  info "Файл конфигурации не найден. Создаем новый..."
  
  # Запрашиваем данные для конфигурации
  read -p "Введите имя домена (по умолчанию: fillin.moscow): " DOMAIN
  DOMAIN=${DOMAIN:-fillin.moscow}
  
  read -p "Введите Cloudflare API Token с правами на редактирование DNS: " CF_API_TOKEN
  
  if [ -z "$CF_API_TOKEN" ]; then
    error "Cloudflare API Token не может быть пустым. Получите токен в панели Cloudflare > Profile > API Tokens > Create Token (используйте шаблон 'Edit zone DNS')."
  fi
  
  # Сохраняем конфигурацию
  cat > "$CONFIG_FILE" << EOF
{
  "domain": "$DOMAIN",
  "cf_api_token": "$CF_API_TOKEN",
  "created_at": "$(date +"%Y-%m-%d %H:%M:%S")"
}
EOF
  
  chmod 600 "$CONFIG_FILE"
  success "Файл конфигурации создан и сохранен в $CONFIG_FILE"
else
  info "Загружаем существующую конфигурацию из $CONFIG_FILE"
  DOMAIN=$(jq -r '.domain' "$CONFIG_FILE")
  CF_API_TOKEN=$(jq -r '.cf_api_token' "$CONFIG_FILE")
  
  # Проверка данных
  if [ -z "$DOMAIN" ] || [ -z "$CF_API_TOKEN" ] || [ "$DOMAIN" == "null" ] || [ "$CF_API_TOKEN" == "null" ]; then
    error "Ошибка в файле конфигурации. Пожалуйста, удалите $CONFIG_FILE и запустите скрипт снова."
  fi
  
  info "Используем домен: $DOMAIN"
fi

# --------------------- Создание временной директории проекта ---------------------

TEMP_DIR=$(mktemp -d)
info "Создана временная директория: $TEMP_DIR"

# Функция для очистки временной директории при выходе
cleanup() {
  info "Очистка временных файлов..."
  rm -rf "$TEMP_DIR"
  info "Работа скрипта завершена."
}

trap cleanup EXIT

# --------------------- Создание файлов проекта для Railway ---------------------

info "Создаем файлы проекта для Railway..."

# Создаем основную структуру
mkdir -p "$TEMP_DIR/nginx/conf.d"
mkdir -p "$TEMP_DIR/app"

# Создаем Dockerfile
cat > "$TEMP_DIR/Dockerfile" << EOF
FROM nginx:alpine

# Копируем конфигурацию Nginx
COPY nginx/conf.d /etc/nginx/conf.d

# Копируем простое приложение
COPY app /usr/share/nginx/html

# Экспортируем переменную PORT для Railway
ENV PORT=8080

# Создаем скрипт для запуска с поддержкой переменной PORT
RUN echo '#!/bin/sh' > /start.sh && \
    echo 'sed -i "s/listen 80/listen \${PORT:-80}/g" /etc/nginx/conf.d/default.conf' >> /start.sh && \
    echo 'nginx -g "daemon off;"' >> /start.sh && \
    chmod +x /start.sh

EXPOSE \${PORT}

# Запуск через скрипт
CMD ["/start.sh"]
EOF

# Создаем nginx конфигурацию
cat > "$TEMP_DIR/nginx/conf.d/default.conf" << EOF
server {
    listen 80;
    server_name $DOMAIN *.$DOMAIN;
    
    # Для обработки всех поддоменов
    if (\$host != "$DOMAIN") {
        # Извлекаем поддомен из имени хоста
        set \$subdomain \$host;
        set \$subdomain "\${subdomain}.$DOMAIN";
        
        # Перенаправляем на /i/ с указанием поддомена
        return 301 https://$DOMAIN/i/\$subdomain\$request_uri;
    }
    
    # Корневая директория
    root /usr/share/nginx/html;
    index index.html;
    
    # Правило для /i/
    location ~ ^/i/([^/]+)(/.*)? {
        add_header Content-Type text/html;
        return 200 '<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CanFly Service</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; line-height: 1.6; }
        h1 { color: #2c3e50; }
        .container { max-width: 800px; margin: 0 auto; padding: 20px; border: 1px solid #ddd; border-radius: 5px; }
        .service-info { background-color: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 20px; }
        .back-link { display: inline-block; margin-top: 20px; padding: 10px 15px; background-color: #3498db; color: white; text-decoration: none; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Сервис: \$1</h1>
        <div class="service-info">
            <p><strong>Поддомен:</strong> \$1.$DOMAIN</p>
            <p><strong>Путь запроса:</strong> \$2</p>
            <p><strong>User-Agent:</strong> \$http_user_agent</p>
            <p><strong>IP:</strong> \$remote_addr</p>
            <p><strong>Дата и время:</strong> \$time_local</p>
        </div>
        <a href="/" class="back-link">Вернуться на главную</a>
    </div>
</body>
</html>';
    }
    
    # Обработка для корневого пути
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    # Статус сервера для проверки
    location /status {
        add_header Content-Type text/plain;
        return 200 "Server is running\nHostname: \$hostname\nDate: \$time_local\nDomain: $DOMAIN";
    }
}
EOF

# Создаем простую HTML страницу
cat > "$TEMP_DIR/app/index.html" << EOF
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CanFly - $DOMAIN</title>
    <style>
        body {
            font-family: 'Arial', sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        header {
            background-color: #3498db;
            color: white;
            padding: 20px;
            text-align: center;
            border-radius: 5px;
            margin-bottom: 20px;
        }
        .container {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
            gap: 20px;
        }
        .service-card {
            border: 1px solid #ddd;
            border-radius: 5px;
            padding: 20px;
            transition: transform 0.3s ease;
        }
        .service-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
        }
        .service-title {
            color: #3498db;
            margin-top: 0;
        }
        .service-link {
            display: inline-block;
            margin-top: 10px;
            padding: 8px 15px;
            background-color: #3498db;
            color: white;
            text-decoration: none;
            border-radius: 3px;
            transition: background-color 0.3s;
        }
        .service-link:hover {
            background-color: #2980b9;
        }
    </style>
</head>
<body>
    <header>
        <h1>CanFly Services</h1>
        <p>Тестовая страница для демонстрации перенаправления поддоменов</p>
    </header>
    
    <main>
        <div class="container">
            <div class="service-card">
                <h2 class="service-title">Почта</h2>
                <p>Почтовый сервис CanFly</p>
                <a href="/i/mail" class="service-link">Открыть сервис</a>
                <a href="https://mail.$DOMAIN" class="service-link">Через поддомен</a>
            </div>
            
            <div class="service-card">
                <h2 class="service-title">Чат</h2>
                <p>Мессенджер для общения</p>
                <a href="/i/chat" class="service-link">Открыть сервис</a>
                <a href="https://chat.$DOMAIN" class="service-link">Через поддомен</a>
            </div>
            
            <div class="service-card">
                <h2 class="service-title">Документы</h2>
                <p>Совместная работа с документами</p>
                <a href="/i/docs" class="service-link">Открыть сервис</a>
                <a href="https://docs.$DOMAIN" class="service-link">Через поддомен</a>
            </div>
            
            <div class="service-card">
                <h2 class="service-title">Календарь</h2>
                <p>Планирование событий и встреч</p>
                <a href="/i/calendar" class="service-link">Открыть сервис</a>
                <a href="https://calendar.$DOMAIN" class="service-link">Через поддомен</a>
            </div>
            
            <div class="service-card">
                <h2 class="service-title">Диск</h2>
                <p>Облачное хранилище файлов</p>
                <a href="/i/drive" class="service-link">Открыть сервис</a>
                <a href="https://drive.$DOMAIN" class="service-link">Через поддомен</a>
            </div>
        </div>
    </main>
    
    <footer style="margin-top: 50px; text-align: center; color: #777;">
        <p>CanFly © 2025. Демонстрационная страница.</p>
        <p>Текущий домен: $DOMAIN</p>
    </footer>
</body>
</html>
EOF

# Создаем файл railway.json
cat > "$TEMP_DIR/railway.json" << EOF
{
  "\$schema": "https://railway.app/railway.schema.json",
  "build": {
    "builder": "DOCKERFILE",
    "dockerfilePath": "Dockerfile"
  },
  "deploy": {
    "healthcheckPath": "/status",
    "healthcheckTimeout": 10,
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 3
  }
}
EOF

# Создаем .gitignore
cat > "$TEMP_DIR/.gitignore" << EOF
.DS_Store
*.log
node_modules
.env
EOF

# --------------------- Создание временного Python-скрипта для Cloudflare DNS ---------------------

cat > "$TEMP_DIR/setup_dns.py" << EOF
#!/usr/bin/env python3
"""
Скрипт для настройки DNS в Cloudflare.
Добавляет wildcard CNAME запись *.domain.com -> domain.com
"""
import json
import sys
import requests
import argparse
import time

def get_zone_id(api_token, domain):
    """Получить zone_id для домена"""
    headers = {
        "Authorization": f"Bearer {api_token}",
        "Content-Type": "application/json"
    }
    
    response = requests.get(
        "https://api.cloudflare.com/client/v4/zones",
        headers=headers
    )
    
    if response.status_code != 200:
        print(f"Ошибка при получении списка зон: {response.status_code}")
        print(response.text)
        return None
    
    zones = response.json().get("result", [])
    for zone in zones:
        if zone["name"] == domain:
            return zone["id"]
    
    print(f"Зона для домена {domain} не найдена.")
    return None

def get_dns_records(api_token, zone_id):
    """Получить все DNS записи для зоны"""
    headers = {
        "Authorization": f"Bearer {api_token}",
        "Content-Type": "application/json"
    }
    
    response = requests.get(
        f"https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_records?per_page=100",
        headers=headers
    )
    
    if response.status_code != 200:
        print(f"Ошибка при получении DNS записей: {response.status_code}")
        print(response.text)
        return None
    
    return response.json().get("result", [])

def create_wildcard_record(api_token, zone_id, domain, railway_url):
    """Создать wildcard CNAME запись *.domain -> railway_url"""
    headers = {
        "Authorization": f"Bearer {api_token}",
        "Content-Type": "application/json"
    }
    
    data = {
        "type": "CNAME",
        "name": f"*.{domain}",
        "content": railway_url,
        "ttl": 1,  # Auto
        "proxied": True
    }
    
    response = requests.post(
        f"https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_records",
        headers=headers,
        json=data
    )
    
    if response.status_code == 200:
        print(f"Wildcard запись *.{domain} -> {railway_url} успешно создана!")
        return True
    else:
        print(f"Ошибка при создании wildcard записи: {response.status_code}")
        print(response.text)
        return False

def update_domain_record(api_token, zone_id, domain, railway_url, record_id=None):
    """Обновить или создать A запись для домена, указывающую на railway_url"""
    headers = {
        "Authorization": f"Bearer {api_token}",
        "Content-Type": "application/json"
    }
    
    data = {
        "type": "CNAME",
        "name": domain,
        "content": railway_url,
        "ttl": 1,  # Auto
        "proxied": True
    }
    
    if record_id:
        # Обновляем существующую запись
        response = requests.put(
            f"https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_records/{record_id}",
            headers=headers,
            json=data
        )
    else:
        # Создаем новую запись
        response = requests.post(
            f"https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_records",
            headers=headers,
            json=data
        )
    
    if response.status_code in [200, 201]:
        print(f"Запись {domain} -> {railway_url} успешно {'обновлена' if record_id else 'создана'}!")
        return True
    else:
        print(f"Ошибка при {'обновлении' if record_id else 'создании'} записи: {response.status_code}")
        print(response.text)
        return False

def setup_dns(api_token, domain, railway_url):
    """Настройка DNS для Railway"""
    print(f"Настройка DNS для домена {domain} -> {railway_url}")
    
    # Получаем ID зоны
    zone_id = get_zone_id(api_token, domain)
    if not zone_id:
        return False
    
    print(f"Найден ID зоны: {zone_id}")
    
    # Получаем текущие записи
    records = get_dns_records(api_token, zone_id)
    if records is None:
        return False
    
    # Проверяем и обновляем основную запись домена
    domain_record_id = None
    wildcard_record_exists = False
    
    for record in records:
        # Проверяем запись для основного домена
        if record["type"] in ["A", "CNAME"] and record["name"] == domain:
            domain_record_id = record["id"]
            print(f"Найдена существующая запись для {domain}: {record['content']}")
        
        # Проверяем wildcard запись
        if record["type"] == "CNAME" and record["name"] == f"*.{domain}":
            wildcard_record_exists = True
            print(f"Wildcard запись *.{domain} уже существует: {record['content']}")
            if record["content"] != railway_url:
                print(f"Обновляем wildcard запись с {record['content']} на {railway_url}")
                update_domain_record(api_token, zone_id, f"*.{domain}", railway_url, record["id"])
    
    # Обновляем или создаем запись для основного домена
    update_result = update_domain_record(api_token, zone_id, domain, railway_url, domain_record_id)
    
    # Создаем wildcard запись, если ее нет
    if not wildcard_record_exists:
        wildcard_result = create_wildcard_record(api_token, zone_id, domain, railway_url)
    else:
        wildcard_result = True
    
    return update_result and wildcard_result

def main():
    parser = argparse.ArgumentParser(description='Настройка DNS для Railway')
    parser.add_argument('--token', required=True, help='Cloudflare API Token')
    parser.add_argument('--domain', required=True, help='Домен (например, example.com)')
    parser.add_argument('--railway-url', required=True, help='URL приложения Railway')
    
    args = parser.parse_args()
    
    success = setup_dns(args.token, args.domain, args.railway_url)
    
    if success:
        print("\nНастройка DNS завершена успешно! 🎉")
        print(f"Теперь ваше приложение доступно по адресу: https://{args.domain}")
        print(f"Поддомены также будут перенаправлены на Railway: https://subdomain.{args.domain}")
    else:
        print("\nПри настройке DNS произошли ошибки. Проверьте логи выше.")
    
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
EOF

chmod +x "$TEMP_DIR/setup_dns.py"

# --------------------- Настройка Git и Railway ---------------------

info "Инициализация Git репозитория и настройка Railway проекта..."

# Переходим во временную директорию
cd "$TEMP_DIR"

# Инициализируем Git репозиторий
git init
git add .
git commit -m "Initial commit for Railway deployment"

# Создаем новый проект в Railway или связываемся с существующим
info "Создаем новый проект в Railway или связываемся с существующим..."
PROJECT_NAME="canfly-$DOMAIN"

# Используем новый синтаксис команд Railway CLI
railway init --name "$PROJECT_NAME" > /dev/null 2>&1
if [ $? -ne 0 ]; then
  warning "Не удалось создать новый проект. Пробуем найти существующий..."
  railway link
  if [ $? -ne 0 ]; then
    error "Не удалось найти или создать проект в Railway."
  fi
fi

info "Проект успешно создан/привязан. Разворачиваем на Railway..."

# Деплоим проект с использованием команды up
railway up
if [ $? -ne 0 ]; then
  error "Не удалось развернуть проект на Railway."
fi

# Проверяем наличие существующего домена или создаем новый
info "Получаем URL приложения..."
railway domain
RAILWAY_URL=$(railway domain 2>/dev/null | grep -oP "https://[^[:space:]]*" | head -1)

if [ -z "$RAILWAY_URL" ]; then
  warning "Не удалось автоматически получить URL. Создаем домен..."
  railway domain
  RAILWAY_URL=$(railway domain | grep -oP "https://[^[:space:]]*" | head -1)
  
  if [ -z "$RAILWAY_URL" ]; then
    error "Не удалось создать или получить URL приложения. Проверьте вручную в панели Railway."
  fi
fi

# Удаляем возможный префикс https://
RAILWAY_URL_CLEAN=$(echo "$RAILWAY_URL" | sed 's|^https://||')

info "Приложение развернуто по адресу: $RAILWAY_URL"

# --------------------- Настройка DNS в Cloudflare ---------------------

info "Настраиваем DNS в Cloudflare..."
info "Домен: $DOMAIN -> $RAILWAY_URL_CLEAN"

# Устанавливаем необходимые Python пакеты
pip3 install requests > /dev/null 2>&1

# Запускаем скрипт для настройки DNS
python3 setup_dns.py --token "$CF_API_TOKEN" --domain "$DOMAIN" --railway-url "$RAILWAY_URL_CLEAN"
if [ $? -ne 0 ]; then
  error "Не удалось настроить DNS в Cloudflare."
fi

# --------------------- Сохранение информации о развертывании ---------------------

# Создаем файл с информацией о развертывании
DEPLOY_INFO_FILE="$CONFIG_DIR/deploy-info.json"
cat > "$DEPLOY_INFO_FILE" << EOF
{
  "domain": "$DOMAIN",
  "railway_url": "$RAILWAY_URL",
  "project_name": "$PROJECT_NAME",
  "deployed_at": "$(date +"%Y-%m-%d %H:%M:%S")"
}
EOF

success "Информация о развертывании сохранена в $DEPLOY_INFO_FILE"

# --------------------- Вывод завершающей информации ---------------------

cat << EOF

🚀 Развертывание завершено успешно! 🚀

📌 Информация о развертывании:
  - Домен: https://$DOMAIN
  - URL Railway: $RAILWAY_URL
  - Имя проекта: $PROJECT_NAME
  - Файл лога: $LOG_FILE
  - Конфигурация: $CONFIG_FILE

⏱ Изменения DNS могут занять до 24 часов для полного распространения,
   но обычно это происходит в течение нескольких минут.

📝 Для проверки работы перенаправления поддоменов:
   1. Откройте https://$DOMAIN
   2. Попробуйте перейти по ссылкам на поддомены, например:
      - https://mail.$DOMAIN
      - https://chat.$DOMAIN

🔧 Для внесения изменений в проект:
   railway login
   cd $TEMP_DIR
   # Внесите необходимые изменения
   railway up

❓ Возникли проблемы? Проверьте лог: $LOG_FILE

EOF 