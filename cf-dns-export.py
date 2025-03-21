#!/usr/bin/env python3
"""
Скрипт для экспорта DNS-записей из Cloudflare с использованием API.
Необходимо иметь API TOKEN с доступом к DNS.
"""

import json
import requests
import sys
import argparse

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
    
    zones = response.json()["result"]
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
    
    return response.json()["result"]

def format_records(records):
    """Форматировать записи в читаемый вид"""
    formatted = []
    for record in records:
        entry = {
            "name": record["name"],
            "type": record["type"],
            "content": record["content"],
            "ttl": record["ttl"],
            "proxied": record.get("proxied", False)
        }
        
        # Добавляем priority для MX и SRV записей
        if "priority" in record:
            entry["priority"] = record["priority"]
        
        formatted.append(entry)
    
    return formatted

def export_dns_records(api_token, domain, output_format="json"):
    """Экспортировать DNS записи для указанного домена"""
    zone_id = get_zone_id(api_token, domain)
    if not zone_id:
        return False
    
    records = get_dns_records(api_token, zone_id)
    if not records:
        return False
    
    formatted_records = format_records(records)
    
    if output_format == "json":
        print(json.dumps(formatted_records, indent=2, ensure_ascii=False))
    elif output_format == "bind":
        print(f"; DNS Zone file for {domain}")
        print(f"$ORIGIN {domain}.")
        print("$TTL 3600")
        
        for record in formatted_records:
            name = record["name"].replace(f".{domain}", "")
            if name == domain:
                name = "@"
            
            ttl = record["ttl"]
            if ttl == 1:  # Auto TTL в Cloudflare
                ttl = 3600
                
            if record["type"] == "MX":
                print(f"{name} {ttl} IN MX {record['priority']} {record['content']}.")
            elif record["type"] == "CNAME":
                print(f"{name} {ttl} IN CNAME {record['content']}.")
            else:
                print(f"{name} {ttl} IN {record['type']} {record['content']}")
    
    return True

def main():
    parser = argparse.ArgumentParser(description='Экспорт DNS записей из Cloudflare')
    parser.add_argument('--token', '-t', required=True, help='Cloudflare API Token')
    parser.add_argument('--domain', '-d', required=True, help='Домен для экспорта')
    parser.add_argument('--format', '-f', choices=['json', 'bind'], default='json',
                        help='Формат вывода (json или bind)')
    
    args = parser.parse_args()
    
    success = export_dns_records(args.token, args.domain, args.format)
    if not success:
        sys.exit(1)

if __name__ == "__main__":
    main() 