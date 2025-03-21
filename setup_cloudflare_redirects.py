#!/usr/bin/env python3
import os
import requests
import json
from dotenv import load_dotenv

# Загрузка переменных окружения из .env файла
load_dotenv()

# Получение API токена из переменных окружения
CLOUDFLARE_API_TOKEN = os.getenv('CLOUDFLARE_API_TOKEN')
if not CLOUDFLARE_API_TOKEN:
    print("Ошибка: CLOUDFLARE_API_TOKEN не найден в файле .env")
    exit(1)

# Настройки
DOMAIN = "fillin.moscow"  # Ваш домен
EMAIL = input("Введите email, привязанный к аккаунту Cloudflare: ")

# Заголовки запросов
headers = {
    "Authorization": f"Bearer {CLOUDFLARE_API_TOKEN}",
    "Content-Type": "application/json"
}

# 1. Получение Zone ID для домена
def get_zone_id():
    url = f"https://api.cloudflare.com/client/v4/zones?name={DOMAIN}"
    response = requests.get(url, headers=headers)
    data = response.json()
    
    if not data['success']:
        print(f"Ошибка при получении Zone ID: {data['errors']}")
        exit(1)
    
    if len(data['result']) == 0:
        print(f"Домен {DOMAIN} не найден в вашем аккаунте Cloudflare")
        exit(1)
    
    zone_id = data['result'][0]['id']
    print(f"Получен Zone ID: {zone_id}")
    return zone_id

# 2. Создание записи DNS для перенаправления всех поддоменов
def create_wildcard_dns_record(zone_id):
    url = f"https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_records"
    
    # Проверяем, существует ли уже запись для поддомена *
    response = requests.get(
        f"{url}?type=CNAME&name=*.{DOMAIN}", 
        headers=headers
    )
    data = response.json()
    
    if data['success'] and len(data['result']) > 0:
        record_id = data['result'][0]['id']
        print(f"Запись для *.{DOMAIN} уже существует (ID: {record_id}). Обновляем...")
        
        # Обновляем существующую запись
        update_url = f"{url}/{record_id}"
        payload = {
            "type": "CNAME",
            "name": f"*.{DOMAIN}",
            "content": DOMAIN,
            "ttl": 1,  # Auto TTL
            "proxied": True
        }
        
        response = requests.put(update_url, headers=headers, json=payload)
    else:
        # Создаем новую запись
        print(f"Создаем новую CNAME запись для *.{DOMAIN}...")
        payload = {
            "type": "CNAME",
            "name": "*",
            "content": DOMAIN,
            "ttl": 1,  # Auto TTL
            "proxied": True
        }
        
        response = requests.post(url, headers=headers, json=payload)
    
    data = response.json()
    if not data['success']:
        print(f"Ошибка при создании/обновлении DNS записи: {data['errors']}")
        return False
    
    print("DNS запись успешно создана/обновлена")
    return True

# 3. Создание Page Rule для перенаправления поддоменов
def create_page_rule(zone_id):
    url = f"https://api.cloudflare.com/client/v4/zones/{zone_id}/pagerules"
    
    # Проверяем существующие правила
    response = requests.get(url, headers=headers)
    data = response.json()
    
    if not data['success']:
        print(f"Ошибка при получении существующих Page Rules: {data['errors']}")
        return False
    
    # Проверяем, существует ли уже правило для *.fillin.moscow/*
    rule_exists = False
    rule_id = None
    
    for rule in data['result']:
        if rule['targets'][0]['constraint']['value'] == f"*.{DOMAIN}/*":
            rule_exists = True
            rule_id = rule['id']
            break
    
    if rule_exists:
        print(f"Page Rule для *.{DOMAIN}/* уже существует (ID: {rule_id}). Обновляем...")
        update_url = f"{url}/{rule_id}"
        
        payload = {
            "targets": [
                {
                    "target": "url",
                    "constraint": {
                        "operator": "matches",
                        "value": f"*.{DOMAIN}/*"
                    }
                }
            ],
            "actions": [
                {
                    "id": "forwarding_url",
                    "value": {
                        "url": f"https://{DOMAIN}/i/$1",
                        "status_code": 301
                    }
                }
            ],
            "status": "active",
            "priority": 1
        }
        
        response = requests.put(update_url, headers=headers, json=payload)
    else:
        # Создаем новое правило
        print(f"Создаем новое Page Rule для *.{DOMAIN}/*...")
        
        payload = {
            "targets": [
                {
                    "target": "url",
                    "constraint": {
                        "operator": "matches",
                        "value": f"*.{DOMAIN}/*"
                    }
                }
            ],
            "actions": [
                {
                    "id": "forwarding_url",
                    "value": {
                        "url": f"https://{DOMAIN}/i/$1",
                        "status_code": 301
                    }
                }
            ],
            "status": "active",
            "priority": 1
        }
        
        response = requests.post(url, headers=headers, json=payload)
    
    data = response.json()
    if not data['success']:
        print(f"Ошибка при создании/обновлении Page Rule: {data['errors']}")
        return False
    
    print("Page Rule успешно создано/обновлено")
    return True

# 4. Создаем дополнительное правило для корневого URL поддомена
def create_root_subdomain_rule(zone_id):
    url = f"https://api.cloudflare.com/client/v4/zones/{zone_id}/pagerules"
    
    # Проверяем существующие правила
    response = requests.get(url, headers=headers)
    data = response.json()
    
    if not data['success']:
        print(f"Ошибка при получении существующих Page Rules: {data['errors']}")
        return False
    
    # Проверяем, существует ли уже правило для *.fillin.moscow
    rule_exists = False
    rule_id = None
    
    for rule in data['result']:
        if rule['targets'][0]['constraint']['value'] == f"*.{DOMAIN}":
            rule_exists = True
            rule_id = rule['id']
            break
    
    if rule_exists:
        print(f"Page Rule для *.{DOMAIN} уже существует (ID: {rule_id}). Обновляем...")
        update_url = f"{url}/{rule_id}"
        
        payload = {
            "targets": [
                {
                    "target": "url",
                    "constraint": {
                        "operator": "matches",
                        "value": f"*.{DOMAIN}"
                    }
                }
            ],
            "actions": [
                {
                    "id": "forwarding_url",
                    "value": {
                        "url": f"https://{DOMAIN}/i/$1",
                        "status_code": 301
                    }
                }
            ],
            "status": "active",
            "priority": 2
        }
        
        response = requests.put(update_url, headers=headers, json=payload)
    else:
        # Создаем новое правило
        print(f"Создаем новое Page Rule для *.{DOMAIN}...")
        
        payload = {
            "targets": [
                {
                    "target": "url",
                    "constraint": {
                        "operator": "matches",
                        "value": f"*.{DOMAIN}"
                    }
                }
            ],
            "actions": [
                {
                    "id": "forwarding_url",
                    "value": {
                        "url": f"https://{DOMAIN}/i/$1",
                        "status_code": 301
                    }
                }
            ],
            "status": "active",
            "priority": 2
        }
        
        response = requests.post(url, headers=headers, json=payload)
    
    data = response.json()
    if not data['success']:
        print(f"Ошибка при создании/обновлении правила для корневого URL поддомена: {data['errors']}")
        return False
    
    print("Правило для корневого URL поддомена успешно создано/обновлено")
    return True

def main():
    print("Настройка перенаправления поддоменов в Cloudflare для", DOMAIN)
    
    # 1. Получаем Zone ID
    zone_id = get_zone_id()
    
    # 2. Создаем запись DNS для поддоменов
    if create_wildcard_dns_record(zone_id):
        print("✓ DNS запись для *.{} создана/обновлена".format(DOMAIN))
    else:
        print("✗ Не удалось создать DNS запись")
    
    # 3. Создаем Page Rule для перенаправления
    if create_page_rule(zone_id):
        print("✓ Page Rule для перенаправления URL с путями создано/обновлено")
    else:
        print("✗ Не удалось создать Page Rule")
    
    # 4. Создаем правило для корневых URL поддоменов
    if create_root_subdomain_rule(zone_id):
        print("✓ Page Rule для перенаправления корневых URL поддоменов создано/обновлено")
    else:
        print("✗ Не удалось создать Page Rule для корневых URL поддоменов")
    
    print("\nНастройка завершена!")
    print(f"Теперь все поддомены *.{DOMAIN} будут перенаправлены на https://{DOMAIN}/i/[поддомен]")

if __name__ == "__main__":
    main() 