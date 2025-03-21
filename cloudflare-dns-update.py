#!/usr/bin/env python3
"""
Скрипт для обновления DNS-записей в Cloudflare для домена fillin.moscow.
API токен считывается из файла .env

Использование:
- Для создания/обновления A-записи:
  python cloudflare-dns-update.py --type A --name sub --content 192.168.1.1

- Для создания/обновления CNAME-записи:
  python cloudflare-dns-update.py --type CNAME --name www --content example.com

- Для удаления записи:
  python cloudflare-dns-update.py --delete --type A --name sub
"""

import os
import requests
import json
import argparse
import sys
from dotenv import load_dotenv

# Константы
DOMAIN = "fillin.moscow"
API_BASE_URL = "https://api.cloudflare.com/client/v4"
DEFAULT_TTL = 1  # Auto TTL в Cloudflare
DEFAULT_PROXIED = True

def load_api_token():
    """Загрузить API токен из файла .env"""
    load_dotenv()
    api_token = os.getenv("CLOUDFLARE_API_TOKEN")
    
    if not api_token:
        try:
            # Если токен не найден через dotenv, попробуем прочитать файл напрямую
            with open(".env", "r") as f:
                api_token = f.read().strip()
        except Exception as e:
            print(f"Ошибка при чтении файла .env: {e}")
            return None
    
    return api_token

def get_zone_id(api_token, domain):
    """Получить zone_id для указанного домена"""
    headers = {
        "Authorization": f"Bearer {api_token}",
        "Content-Type": "application/json"
    }
    
    response = requests.get(
        f"{API_BASE_URL}/zones",
        headers=headers
    )
    
    if response.status_code != 200:
        print(f"Ошибка при получении списка зон: {response.status_code}")
        print(response.text)
        return None
    
    zones = response.json()["result"]
    for zone in zones:
        if zone["name"] == domain:
            return zone["id"]
    
    print(f"Зона для домена {domain} не найдена.")
    return None

def find_dns_record(api_token, zone_id, record_type, record_name):
    """Найти DNS запись по типу и имени"""
    full_name = f"{record_name}.{DOMAIN}" if record_name != "@" else DOMAIN
    
    headers = {
        "Authorization": f"Bearer {api_token}",
        "Content-Type": "application/json"
    }
    
    response = requests.get(
        f"{API_BASE_URL}/zones/{zone_id}/dns_records?type={record_type}&name={full_name}",
        headers=headers
    )
    
    if response.status_code != 200:
        print(f"Ошибка при поиске DNS записи: {response.status_code}")
        print(response.text)
        return None
    
    records = response.json()["result"]
    if records:
        return records[0]  # Возвращаем первую найденную запись
    
    return None

def create_dns_record(api_token, zone_id, record_type, record_name, content, ttl=DEFAULT_TTL, proxied=DEFAULT_PROXIED):
    """Создать новую DNS запись"""
    full_name = f"{record_name}.{DOMAIN}" if record_name != "@" else DOMAIN
    
    headers = {
        "Authorization": f"Bearer {api_token}",
        "Content-Type": "application/json"
    }
    
    data = {
        "type": record_type,
        "name": full_name,
        "content": content,
        "ttl": ttl,
        "proxied": proxied
    }
    
    response = requests.post(
        f"{API_BASE_URL}/zones/{zone_id}/dns_records",
        headers=headers,
        json=data
    )
    
    if response.status_code not in [200, 201]:
        print(f"Ошибка при создании DNS записи: {response.status_code}")
        print(response.text)
        return False
    
    print(f"DNS запись успешно создана: {full_name} {record_type} {content}")
    return True

def update_dns_record(api_token, zone_id, record_id, record_type, record_name, content, ttl=DEFAULT_TTL, proxied=DEFAULT_PROXIED):
    """Обновить существующую DNS запись"""
    full_name = f"{record_name}.{DOMAIN}" if record_name != "@" else DOMAIN
    
    headers = {
        "Authorization": f"Bearer {api_token}",
        "Content-Type": "application/json"
    }
    
    data = {
        "type": record_type,
        "name": full_name,
        "content": content,
        "ttl": ttl,
        "proxied": proxied
    }
    
    response = requests.put(
        f"{API_BASE_URL}/zones/{zone_id}/dns_records/{record_id}",
        headers=headers,
        json=data
    )
    
    if response.status_code != 200:
        print(f"Ошибка при обновлении DNS записи: {response.status_code}")
        print(response.text)
        return False
    
    print(f"DNS запись успешно обновлена: {full_name} {record_type} {content}")
    return True

def delete_dns_record(api_token, zone_id, record_id, record_name, record_type):
    """Удалить DNS запись"""
    full_name = f"{record_name}.{DOMAIN}" if record_name != "@" else DOMAIN
    
    headers = {
        "Authorization": f"Bearer {api_token}",
        "Content-Type": "application/json"
    }
    
    response = requests.delete(
        f"{API_BASE_URL}/zones/{zone_id}/dns_records/{record_id}",
        headers=headers
    )
    
    if response.status_code != 200:
        print(f"Ошибка при удалении DNS записи: {response.status_code}")
        print(response.text)
        return False
    
    print(f"DNS запись успешно удалена: {full_name} {record_type}")
    return True

def main():
    parser = argparse.ArgumentParser(description='Обновление DNS записей в Cloudflare для домена fillin.moscow')
    parser.add_argument('--type', choices=['A', 'CNAME'], required=True, help='Тип DNS записи')
    parser.add_argument('--name', required=True, help='Имя записи (субдомен)')
    parser.add_argument('--content', help='Содержимое записи (IP для A, домен для CNAME)')
    parser.add_argument('--ttl', type=int, default=DEFAULT_TTL, help='TTL (время жизни) записи в секундах')
    parser.add_argument('--proxied', type=bool, default=DEFAULT_PROXIED, help='Использовать ли Cloudflare CDN')
    parser.add_argument('--delete', action='store_true', help='Удалить запись вместо создания/обновления')
    
    args = parser.parse_args()
    
    # Проверяем, что при удалении не указан content
    if args.delete and args.content:
        print("Ошибка: нельзя указывать --content при удалении записи")
        sys.exit(1)
    
    # Проверяем, что при создании/обновлении записи указан content
    if not args.delete and not args.content:
        print("Ошибка: необходимо указать --content для создания или обновления записи")
        sys.exit(1)
    
    # Загружаем API токен
    api_token = load_api_token()
    if not api_token:
        print("Ошибка: API токен не найден")
        print("Убедитесь, что файл .env существует и содержит токен Cloudflare API")
        sys.exit(1)
    
    # Получаем zone_id
    zone_id = get_zone_id(api_token, DOMAIN)
    if not zone_id:
        print(f"Ошибка: не удалось получить zone_id для домена {DOMAIN}")
        sys.exit(1)
    
    # Ищем существующую запись
    existing_record = find_dns_record(api_token, zone_id, args.type, args.name)
    
    if args.delete:
        # Удаляем запись, если она существует
        if existing_record:
            success = delete_dns_record(api_token, zone_id, existing_record["id"], args.name, args.type)
            sys.exit(0 if success else 1)
        else:
            print(f"Запись {args.name}.{DOMAIN} типа {args.type} не найдена")
            sys.exit(0)  # Не считаем ошибкой, если запись для удаления не существует
    else:
        # Создаем или обновляем запись
        if existing_record:
            # Запись уже существует, обновляем
            success = update_dns_record(
                api_token, zone_id, existing_record["id"], args.type, args.name, 
                args.content, args.ttl, args.proxied
            )
        else:
            # Записи нет, создаем новую
            success = create_dns_record(
                api_token, zone_id, args.type, args.name, 
                args.content, args.ttl, args.proxied
            )
        
        sys.exit(0 if success else 1)

if __name__ == "__main__":
    main() 