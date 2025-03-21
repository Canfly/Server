#!/usr/bin/env bash

# canfly | культура твоего сознания» 

# --------------------- Вспомогательные функции ---------------------

# Цветной вывод для удобства чтения
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для вывода сообщений
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Проверка наличия необходимых команд
check_command() {
  command -v $1 >/dev/null 2>&1 || { error "Пожалуйста, установите $1"; }
}

# --------------------- Проверка предварительных условий ---------------------

# Проверяем, что скрипт запущен с правами администратора
if [ "$(id -u)" != "0" ]; then
   error "Этот скрипт должен быть запущен с правами суперпользователя (sudo)"
fi

# Проверяем наличие необходимых утилит
check_command curl
check_command docker
check_command docker-compose
check_command openssl

# --------------------- Загрузка конфигурации ---------------------

# Создаем директорию для проекта, если она не существует
PROJECT_DIR="/opt/canfly"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# Загружаем или создаем .env файл
if [ ! -f .env ]; then
  info "Создаем файл .env для настройки..."
  cat > .env << EOF
# Настройки Cloudflare API
CLOUDFLARE_API_TOKEN=

# Домен
DOMAIN=canfly.org

# Настройки для Nginx
NGINX_SSL_CERT_PATH=/etc/nginx/ssl/canfly.org.crt
NGINX_SSL_KEY_PATH=/etc/nginx/ssl/canfly.org.key

# Настройки для NuxtJS
NUXT_PORT=3000
EOF
  warning "Файл .env создан. Пожалуйста, отредактируйте его, добавив API TOKEN Cloudflare и другие настройки."
  warning "После этого запустите скрипт снова."
  exit 0
fi

# Загружаем .env файл
source .env

# Проверяем наличие API TOKEN Cloudflare
if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
  error "API TOKEN Cloudflare не указан в файле .env. Пожалуйста, добавьте его и запустите скрипт снова."
fi

# --------------------- Настройка структуры проекта ---------------------

info "Создаем структуру проекта..."

# Создаем директории
mkdir -p nginx/conf.d
mkdir -p nginx/ssl
mkdir -p nginx/logs
mkdir -p nuxt-app/server-middleware
mkdir -p nuxt-app/pages/i

# --------------------- Создание конфигурационных файлов ---------------------

info "Создаем конфигурационные файлы..."

# Создаем docker-compose.yml
cat > docker-compose.yml << EOF
version: '3'

services:
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d
      - ./nginx/ssl:/etc/nginx/ssl
      - ./nginx/logs:/var/log/nginx
    depends_on:
      - nuxt
    restart: always
    networks:
      - canfly-network
  
  nuxt:
    build:
      context: ./nuxt-app
      dockerfile: Dockerfile
    environment:
      - NODE_ENV=production
      - PORT=${NUXT_PORT}
    expose:
      - "${NUXT_PORT}"
    restart: always
    networks:
      - canfly-network
    volumes:
      - ./nuxt-app:/app
      - nuxt_node_modules:/app/node_modules

networks:
  canfly-network:
    driver: bridge

volumes:
  nuxt_node_modules:
EOF

# Создаем конфигурацию Nginx
cat > nginx/conf.d/canfly.conf << EOF
# Основная конфигурация для ${DOMAIN}
# Обрабатывает поддомены и перенаправляет их на /i/

server {
    listen 80;
    server_name ${DOMAIN} *.${DOMAIN};
    
    # Перенаправление всего HTTP-трафика на HTTPS
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${DOMAIN} *.${DOMAIN};
    
    # SSL-настройки 
    ssl_certificate ${NGINX_SSL_CERT_PATH};
    ssl_certificate_key ${NGINX_SSL_KEY_PATH};
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    # Общие настройки безопасности
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options SAMEORIGIN;
    
    # Правило перенаправления для поддоменов
    if (\$host != "${DOMAIN}") {
        # Извлекаем поддомен из имени хоста
        set \$subdomain \$host;
        set \$subdomain "\${subdomain/.${DOMAIN}/}";
        
        # Перенаправляем на /i/ с указанием поддомена
        return 301 https://${DOMAIN}/i/\$subdomain\$request_uri;
    }
    
    # Обработка запросов к /i/ через локальное NuxtJS приложение
    location ^~ /i/ {
        proxy_pass http://nuxt:${NUXT_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Передаем необходимые заголовки в NuxtJS
        proxy_set_header X-Original-Host \$http_host;
        proxy_set_header X-Original-URI \$request_uri;
        
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    
    # Все остальные запросы проксируем на Vercel
    location / {
        proxy_pass https://${DOMAIN}.vercel.org;
        proxy_set_header Host ${DOMAIN}.vercel.org;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        proxy_cache_bypass \$http_upgrade;
        proxy_ssl_server_name on;
    }
    
    # Логи
    access_log /var/log/nginx/canfly.access.log;
    error_log /var/log/nginx/canfly.error.log;
}
EOF

# Dockerfile для NuxtJS
cat > nuxt-app/Dockerfile << EOF
FROM node:18-alpine

WORKDIR /app

# Копируем файлы зависимостей
COPY package*.json ./

# Устанавливаем зависимости
RUN npm ci

# Копируем исходный код
COPY . .

# Собираем приложение
RUN npm run build

# Запускаем приложение
CMD [ "npm", "run", "start" ]
EOF

# package.json для NuxtJS
cat > nuxt-app/package.json << EOF
{
  "name": "canfly-nuxt-app",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "nuxt",
    "build": "nuxt build",
    "start": "nuxt start",
    "generate": "nuxt generate"
  },
  "dependencies": {
    "nuxt": "^2.15.8",
    "core-js": "^3.25.3",
    "vue": "^2.7.10",
    "vue-server-renderer": "^2.7.10",
    "vue-template-compiler": "^2.7.10"
  },
  "devDependencies": {
    "@nuxt/types": "^2.15.8",
    "@nuxt/typescript-build": "^2.1.0"
  }
}
EOF

# nuxt.config.js
cat > nuxt-app/nuxt.config.js << EOF
export default {
  // Глобальные настройки страницы
  head: {
    title: 'CanFly - Сервисы',
    meta: [
      { charset: 'utf-8' },
      { name: 'viewport', content: 'width=device-width, initial-scale=1' },
      { hid: 'description', name: 'description', content: 'CanFly - Микросервисы' }
    ],
    link: [
      { rel: 'icon', type: 'image/x-icon', href: '/favicon.ico' }
    ]
  },

  // Глобальный CSS
  css: [
  ],

  // Плагины, которые загружаются перед монтированием приложения
  plugins: [
  ],

  // Компоненты автоматически импортируются
  components: true,

  // Модули разработки
  buildModules: [
    '@nuxt/typescript-build',
  ],

  // Модули
  modules: [
  ],

  // Серверный посредник для обработки поддоменов
  serverMiddleware: [
    '~/server-middleware/subdomain-handler.js'
  ],

  // Настройки сервера
  server: {
    port: process.env.PORT || ${NUXT_PORT},
    host: '0.0.0.0'
  },

  // Настройки сборки
  build: {
  }
}
EOF

# Middleware для обработки поддоменов
cat > nuxt-app/server-middleware/subdomain-handler.js << EOF
/**
 * Middleware для обработки запросов от поддоменов, которые были перенаправлены на /i/
 */
export default function (req, res, next) {
  // Получаем информацию о пути из URL
  const url = new URL(req.url, \`http://\${req.headers.host}\`);
  const pathParts = url.pathname.split('/').filter(Boolean);
  
  // Мы ожидаем, что запросы будут в формате /i/[subdomain]/[path]
  if (pathParts[0] === 'i' && pathParts.length > 1) {
    const subdomain = pathParts[1];
    
    // Сохраняем информацию о поддомене в объекте запроса для использования в компонентах
    req.subdomain = subdomain;
    
    // Удаляем поддомен из пути, т.к. он уже обработан как параметр
    // Например, /i/mail/inbox -> /i/inbox
    if (pathParts.length > 2) {
      const newPath = '/i/' + pathParts.slice(2).join('/');
      url.pathname = newPath;
      req.url = url.pathname + url.search;
    }
    
    console.log(\`Обработка запроса от поддомена: \${subdomain}, новый путь: \${req.url}\`);
  } else if (pathParts[0] === 'i' && pathParts.length === 1) {
    // Если просто /i/ без поддомена, покажем список сервисов
    console.log('Запрос к списку сервисов');
  }
  
  // Также можно добавить информацию из заголовков, если перенаправление сделано через Nginx
  const originalHost = req.headers['x-original-host'];
  if (originalHost && originalHost !== '${DOMAIN}') {
    // Извлекаем поддомен из заголовка
    const subdomainFromHeader = originalHost.replace('.${DOMAIN}', '');
    req.subdomainFromHeader = subdomainFromHeader;
  }
  
  next();
}
EOF

# Создаем страницу списка сервисов
cat > nuxt-app/pages/i/index.vue << EOF
<template>
  <div class="services-container">
    <h1>Сервисы CanFly</h1>
    
    <div class="services-grid">
      <div v-for="service in services" :key="service.id" class="service-card">
        <div class="service-icon" :class="service.icon"></div>
        <h2>{{ service.name }}</h2>
        <p>{{ service.description }}</p>
        <nuxt-link :to="\`/i/\${service.id}\`" class="service-link">Открыть сервис</nuxt-link>
      </div>
    </div>
  </div>
</template>

<script>
export default {
  data() {
    return {
      services: [
        {
          id: 'mail',
          name: 'Почта',
          description: 'Почтовый сервис CanFly',
          icon: 'mail-icon'
        },
        {
          id: 'chat',
          name: 'Чат',
          description: 'Мессенджер для общения',
          icon: 'chat-icon'
        },
        {
          id: 'docs',
          name: 'Документы',
          description: 'Совместная работа с документами',
          icon: 'docs-icon'
        },
        {
          id: 'calendar',
          name: 'Календарь',
          description: 'Планирование событий и встреч',
          icon: 'calendar-icon'
        },
        {
          id: 'drive',
          name: 'Диск',
          description: 'Облачное хранилище файлов',
          icon: 'drive-icon'
        }
      ]
    };
  },
  head() {
    return {
      title: 'CanFly - Все сервисы'
    };
  }
};
</script>

<style scoped>
.services-container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 2rem;
}

h1 {
  text-align: center;
  margin-bottom: 2rem;
  color: #2c3e50;
}

.services-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
  gap: 2rem;
}

.service-card {
  background: #fff;
  border-radius: 8px;
  padding: 1.5rem;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
  transition: transform 0.3s ease, box-shadow 0.3s ease;
}

.service-card:hover {
  transform: translateY(-5px);
  box-shadow: 0 12px 16px rgba(0, 0, 0, 0.1);
}

.service-icon {
  width: 60px;
  height: 60px;
  margin-bottom: 1rem;
  background-color: #f0f4f8;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
}

h2 {
  margin-bottom: 0.5rem;
  color: #2c3e50;
}

p {
  color: #606f7b;
  margin-bottom: 1.5rem;
}

.service-link {
  display: inline-block;
  padding: 0.5rem 1rem;
  background-color: #3498db;
  color: white;
  text-decoration: none;
  border-radius: 4px;
  font-weight: 500;
  transition: background-color 0.3s ease;
}

.service-link:hover {
  background-color: #2980b9;
}
</style>
EOF

# Создаем динамический роутер для сервисов
cat > nuxt-app/pages/i/_service.vue << EOF
<template>
  <div class="service-container">
    <div class="service-header">
      <nuxt-link to="/i" class="back-button">← Все сервисы</nuxt-link>
      <h1>{{ serviceName }}</h1>
    </div>
    
    <div v-if="serviceExists" class="service-content">
      <div class="service-info">
        <p>Вы открыли сервис <strong>{{ \$route.params.service }}</strong>.</p>
        <p>В полной версии здесь будет отображаться содержимое данного сервиса.</p>
        <p>Этот сервис также доступен по ссылке: <a :href="subdomainUrl" target="_blank">{{ subdomainUrl }}</a></p>
      </div>
      
      <div class="service-mock">
        <h2>Демо-интерфейс</h2>
        <div class="mock-ui">
          <div class="mock-sidebar">
            <div v-for="(item, index) in mockSidebarItems" :key="index" class="mock-sidebar-item">
              {{ item }}
            </div>
          </div>
          <div class="mock-content">
            <div class="mock-header"></div>
            <div class="mock-body">
              <div v-for="i in 4" :key="i" class="mock-item"></div>
            </div>
          </div>
        </div>
      </div>
    </div>
    
    <div v-else class="service-not-found">
      <h2>Сервис не найден</h2>
      <p>Запрошенный сервис "{{ \$route.params.service }}" не существует или недоступен.</p>
      <nuxt-link to="/i" class="back-link">Вернуться к списку сервисов</nuxt-link>
    </div>
  </div>
</template>

<script>
export default {
  data() {
    return {
      availableServices: ['mail', 'chat', 'docs', 'calendar', 'drive'],
      serviceNames: {
        mail: 'Почтовый сервис',
        chat: 'Мессенджер',
        docs: 'Документы',
        calendar: 'Календарь',
        drive: 'Облачное хранилище'
      },
      mockSidebarItems: ['Элемент 1', 'Элемент 2', 'Элемент 3', 'Элемент 4', 'Элемент 5']
    };
  },
  computed: {
    serviceExists() {
      return this.availableServices.includes(this.\$route.params.service);
    },
    serviceName() {
      const service = this.\$route.params.service;
      return this.serviceNames[service] || service;
    },
    subdomainUrl() {
      return \`https://\${this.\$route.params.service}.${DOMAIN}\`;
    }
  },
  head() {
    return {
      title: this.serviceExists 
        ? \`CanFly - \${this.serviceName}\` 
        : 'Сервис не найден'
    };
  }
};
</script>

<style scoped>
.service-container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 2rem;
}

.service-header {
  margin-bottom: 2rem;
  display: flex;
  flex-direction: column;
}

.back-button {
  display: inline-block;
  margin-bottom: 1rem;
  color: #3498db;
  text-decoration: none;
  font-weight: 500;
}

h1 {
  color: #2c3e50;
}

.service-content {
  display: grid;
  grid-template-columns: 1fr;
  gap: 2rem;
}

@media (min-width: 768px) {
  .service-content {
    grid-template-columns: 1fr 2fr;
  }
}

.service-info {
  background: #fff;
  padding: 1.5rem;
  border-radius: 8px;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
}

.service-mock {
  background: #fff;
  padding: 1.5rem;
  border-radius: 8px;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
}

.mock-ui {
  display: flex;
  height: 400px;
  border: 1px solid #e0e0e0;
  border-radius: 4px;
  overflow: hidden;
  margin-top: 1rem;
}

.mock-sidebar {
  width: 200px;
  background-color: #f5f5f5;
  padding: 1rem;
  border-right: 1px solid #e0e0e0;
}

.mock-sidebar-item {
  padding: 0.75rem 1rem;
  margin-bottom: 0.5rem;
  background-color: #fff;
  border-radius: 4px;
  cursor: pointer;
  transition: background-color 0.2s;
}

.mock-sidebar-item:hover {
  background-color: #e3f2fd;
}

.mock-content {
  flex: 1;
  display: flex;
  flex-direction: column;
}

.mock-header {
  height: 60px;
  background-color: #f9f9f9;
  border-bottom: 1px solid #e0e0e0;
}

.mock-body {
  flex: 1;
  padding: 1rem;
  overflow-y: auto;
}

.mock-item {
  height: 80px;
  background-color: #f5f5f5;
  margin-bottom: 1rem;
  border-radius: 4px;
}

.service-not-found {
  text-align: center;
  background: #fff;
  padding: 3rem;
  border-radius: 8px;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
}

.back-link {
  display: inline-block;
  margin-top: 1rem;
  padding: 0.5rem 1rem;
  background-color: #3498db;
  color: white;
  text-decoration: none;
  border-radius: 4px;
  font-weight: 500;
}
</style>
EOF

# --------------------- Создание скрипта для DNS Cloudflare ---------------------

# Создаем скрипт для работы с DNS Cloudflare
cat > cf-dns-setup.py << EOF
#!/usr/bin/env python3
"""
Скрипт для настройки DNS-записей в Cloudflare для проекта CanFly.
Автоматически создает wildcard CNAME запись *.canfly.org -> canfly.org
"""

import json
import os
import requests
import sys

# Загружаем переменные окружения из .env
CLOUDFLARE_API_TOKEN = os.environ.get('CLOUDFLARE_API_TOKEN')
DOMAIN = os.environ.get('DOMAIN', 'canfly.org')

def get_zone_id(api_token, domain):
    """Получить zone_id для указанного домена"""
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
    """Получить все DNS записи для указанной зоны"""
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

def create_wildcard_record(api_token, zone_id, domain):
    """Создать wildcard CNAME запись *.domain -> domain"""
    headers = {
        "Authorization": f"Bearer {api_token}",
        "Content-Type": "application/json"
    }
    
    data = {
        "type": "CNAME",
        "name": f"*.{domain}",
        "content": domain,
        "ttl": 1,  # Auto
        "proxied": True
    }
    
    response = requests.post(
        f"https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_records",
        headers=headers,
        json=data
    )
    
    if response.status_code == 200:
        print(f"Wildcard запись *.{domain} -> {domain} успешно создана!")
        return True
    else:
        print(f"Ошибка при создании wildcard записи: {response.status_code}")
        print(response.text)
        return False

def check_and_create_wildcard(api_token, domain):
    """Проверить наличие wildcard записи и создать ее при необходимости"""
    zone_id = get_zone_id(api_token, domain)
    if not zone_id:
        return False
    
    records = get_dns_records(api_token, zone_id)
    if records is None:
        return False
    
    # Проверяем наличие wildcard записи
    wildcard_exists = False
    for record in records:
        if record["type"] == "CNAME" and record["name"] == f"*.{domain}":
            wildcard_exists = True
            print(f"Wildcard запись *.{domain} уже существует!")
            break
    
    # Если записи нет, создаем ее
    if not wildcard_exists:
        return create_wildcard_record(api_token, zone_id, domain)
    
    return True

def main():
    # Проверяем наличие токена API
    if not CLOUDFLARE_API_TOKEN:
        print("Ошибка: API-токен Cloudflare не найден в переменных окружения.")
        print("Пожалуйста, добавьте CLOUDFLARE_API_TOKEN в файл .env")
        sys.exit(1)
    
    # Настраиваем DNS
    success = check_and_create_wildcard(CLOUDFLARE_API_TOKEN, DOMAIN)
    
    if not success:
        print("Не удалось настроить DNS-записи. Пожалуйста, проверьте API-токен и попробуйте снова.")
        sys.exit(1)
    
    print("DNS-настройка завершена успешно!")

if __name__ == "__main__":
    main()
EOF

chmod +x cf-dns-setup.py

# --------------------- Проверка и создание SSL-сертификатов ---------------------

info "Проверка SSL-сертификатов..."

# Проверяем наличие SSL-сертификатов
mkdir -p nginx/ssl

if [ ! -f "$NGINX_SSL_CERT_PATH" ] || [ ! -f "$NGINX_SSL_KEY_PATH" ]; then
  warning "SSL-сертификаты не найдены. Для продакшена рекомендуется использовать Let's Encrypt."
  info "Создаем самоподписанные сертификаты для тестирования..."
  
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout nginx/ssl/canfly.org.key \
    -out nginx/ssl/canfly.org.crt \
    -subj "/CN=${DOMAIN}/O=CanFly/C="
fi
