# CanFly Railway Deployment

Проект для развертывания инфраструктуры CanFly на платформе Railway.app с поддержкой поддоменов через Cloudflare DNS.

## Особенности проекта

- 🚂 Развертывание на платформе [Railway.app](https://railway.app)
- 🔄 Перенаправление поддоменов в пути `/i/[service]`
- 🛡️ Интеграция с Cloudflare DNS
- 📊 Подробное логирование всех операций
- 🧩 Простое добавление новых сервисов

## Начало работы

### Предварительные требования

1. Установленный [Railway CLI](https://docs.railway.app/develop/cli)
2. Домен, настроенный на Cloudflare
3. Python 3 и pip
4. curl, jq (для работы скрипта)

### Установка

1. Клонируйте репозиторий:

```bash
git clone https://github.com/yourusername/canfly-railway.git
cd canfly-railway
```

2. Получите API токен Cloudflare (см. [cloudflare-api-setup.md](cloudflare-api-setup.md))

3. Запустите скрипт развертывания:

```bash
chmod +x railway-deploy.sh
./railway-deploy.sh
```

4. Следуйте инструкциям в консоли

## Структура проекта

```
/
├── railway-deploy.sh        # Основной скрипт развертывания
├── cloudflare-api-setup.md  # Инструкция по настройке Cloudflare API
└── README.md                # Эта документация
```

После запуска скрипта создается временная директория с проектом, которая отправляется на Railway:

```
/tmp/temp-dir/
├── app/                      # Статические файлы для Nginx
│   └── index.html            # Демонстрационная страница
├── nginx/                    # Конфигурация Nginx
│   └── conf.d/
│       └── default.conf      # Основная конфигурация с обработкой поддоменов
├── Dockerfile                # Dockerfile для сборки образа
├── railway.json              # Конфигурация для Railway
└── ... (другие служебные файлы)
```

## Как это работает

1. Скрипт создает проект на Railway с Nginx сервером
2. Настраивает DNS записи в Cloudflare для основного домена и wildcard поддомена
3. Nginx обрабатывает запросы и перенаправляет поддомены в пути `/i/[service]`

### Пример переадресации

- Запрос к `https://mail.fillin.moscow` будет автоматически перенаправлен на `https://fillin.moscow/i/mail`
- Аналогично работает для любых других поддоменов

## Настройка существующего проекта

Если вы уже запускали скрипт и хотите внести изменения:

```bash
# Войдите в Railway CLI
railway login

# Найдите директорию с временными файлами в логах
grep "Создана временная директория" ~/.railway-canfly-logs/deploy-*.log | tail -1

# Перейдите в эту директорию и внесите изменения
cd /tmp/temp-dir-example
# Внесите изменения...

# Разверните обновления
railway up
```

## Логи и отладка

- Логи сохраняются в директории `~/.railway-canfly-logs/`
- Конфигурация хранится в `~/.railway-canfly-config/`

## Лицензия

MIT 