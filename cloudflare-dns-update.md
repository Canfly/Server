# Обновление DNS записей Cloudflare для домена fillin.moscow

Этот набор скриптов предназначен для управления DNS-записями в Cloudflare для домена fillin.moscow. Скрипты позволяют создавать, обновлять и удалять A и CNAME записи.

## Требования

- Python 3
- Пакеты Python: `requests`, `python-dotenv`
- API токен Cloudflare с правами редактирования DNS записей (см. инструкцию в `cloudflare-api-setup.md`)

## Настройка

1. Убедитесь, что файл `.env` содержит ваш API-токен Cloudflare в следующем формате:

```
CLOUDFLARE_API_TOKEN=ваш_токен_здесь
```

2. Сделайте скрипты исполняемыми:

```bash
chmod +x cloudflare-dns-update.py update-dns.sh
```

## Использование Bash-скрипта (рекомендуется)

Bash-скрипт `update-dns.sh` является удобной оболочкой для Python-скрипта, предоставляя простой интерфейс командной строки.

### Примеры использования:

#### Добавление/обновление A-записи (прямое связывание поддомена с IP-адресом)
```bash
./update-dns.sh add-a api 192.168.1.1
```

#### Добавление/обновление CNAME-записи (перенаправление поддомена на другой домен)
```bash
./update-dns.sh add-cname dev example.com
```

#### Удаление A-записи
```bash
./update-dns.sh delete-a old-api
```

#### Удаление CNAME-записи
```bash
./update-dns.sh delete-cname old-dev
```

#### Обновление корневой A-записи (для домена fillin.moscow без поддомена)
```bash
./update-dns.sh root 203.0.113.1
```

#### Обновление www записи (для www.fillin.moscow)
```bash
./update-dns.sh www fillin.moscow
```

## Использование Python-скрипта напрямую

Если требуется более гибкая настройка, можно использовать Python-скрипт напрямую:

### Примеры использования:

#### Добавление/обновление A-записи
```bash
./cloudflare-dns-update.py --type A --name api --content 192.168.1.1
```

#### Добавление/обновление CNAME-записи
```bash
./cloudflare-dns-update.py --type CNAME --name dev --content example.com
```

#### Добавление записи с указанием TTL и без Cloudflare CDN
```bash
./cloudflare-dns-update.py --type A --name direct --content 192.168.1.2 --ttl 3600 --proxied False
```

#### Удаление записи
```bash
./cloudflare-dns-update.py --delete --type A --name old-api
```

## Интеграция с CI/CD

Скрипт можно использовать в процессах CI/CD для автоматического обновления DNS-записей после деплоя.

Пример для Railway:
```bash
# После успешного деплоя на Railway обновляем А-запись 
./update-dns.sh add-a api $RAILWAY_PUBLIC_IP
```

## Устранение неполадок

1. **Ошибка API токена**: Убедитесь, что токен в файле `.env` корректен и имеет разрешения на редактирование DNS.

2. **Ошибка зоны**: Проверьте, что указанный домен доступен в вашей учетной записи Cloudflare.

3. **Ошибка импорта Python модулей**: Установите необходимые зависимости:
   ```bash
   pip install requests python-dotenv
   ``` 