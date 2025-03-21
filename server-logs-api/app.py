#!/usr/bin/env python3
import os
import json
import logging
from datetime import datetime
from flask import Flask, request, jsonify
from flask_cors import CORS
import hashlib

app = Flask(__name__)
CORS(app)

# Настройка логирования
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler("server_logs_api.log")
    ]
)
logger = logging.getLogger(__name__)

# Путь к директории для хранения логов
LOG_STORAGE_DIR = os.environ.get('LOG_STORAGE_DIR', 'logs')
os.makedirs(LOG_STORAGE_DIR, exist_ok=True)

# API ключ для авторизации
API_KEY = os.environ.get('API_KEY', 'your-secret-api-key')  # Используйте безопасный ключ в production

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({"status": "ok", "timestamp": datetime.now().isoformat()})

@app.route('/logs', methods=['POST'])
def receive_logs():
    # Проверка авторизации
    auth_header = request.headers.get('Authorization')
    if not auth_header or not auth_header.startswith('Bearer ') or auth_header[7:] != API_KEY:
        logger.warning(f"Unauthorized access attempt from IP: {request.remote_addr}")
        return jsonify({"error": "Unauthorized"}), 401
    
    try:
        # Получение данных
        data = request.json
        
        if not isinstance(data, list):
            data = [data]
        
        # Сохранение логов в файлы
        for log_entry in data:
            log_type = log_entry.get('@metadata', {}).get('beat', 'unknown')
            
            # Генерация имени файла на основе текущей даты и типа лога
            now = datetime.now()
            date_str = now.strftime("%Y-%m-%d")
            hour_str = now.strftime("%H")
            
            # Создание директорий если не существуют
            log_dir = os.path.join(LOG_STORAGE_DIR, log_type, date_str)
            os.makedirs(log_dir, exist_ok=True)
            
            # Имя файла будет содержать час и случайный хеш для уникальности
            random_hash = hashlib.md5(str(now.timestamp()).encode()).hexdigest()[:8]
            filename = f"{hour_str}_{random_hash}.json"
            
            # Запись лога в файл
            log_path = os.path.join(log_dir, filename)
            with open(log_path, 'w') as f:
                json.dump(log_entry, f, indent=2)
            
            logger.info(f"Saved log entry to {log_path}")
        
        return jsonify({"status": "success", "count": len(data)}), 200
    
    except Exception as e:
        logger.error(f"Error processing logs: {str(e)}", exc_info=True)
        return jsonify({"error": str(e)}), 500

@app.route('/logs/list', methods=['GET'])
def list_logs():
    # Проверка авторизации
    auth_header = request.headers.get('Authorization')
    if not auth_header or not auth_header.startswith('Bearer ') or auth_header[7:] != API_KEY:
        return jsonify({"error": "Unauthorized"}), 401
    
    try:
        log_type = request.args.get('type', 'all')
        date = request.args.get('date', datetime.now().strftime("%Y-%m-%d"))
        
        result = {"logs": []}
        
        if log_type == 'all':
            # Получение списка всех типов логов
            log_types = [d for d in os.listdir(LOG_STORAGE_DIR) 
                        if os.path.isdir(os.path.join(LOG_STORAGE_DIR, d))]
        else:
            log_types = [log_type]
        
        for lt in log_types:
            log_dir = os.path.join(LOG_STORAGE_DIR, lt, date)
            if os.path.exists(log_dir):
                log_files = os.listdir(log_dir)
                for log_file in log_files:
                    result["logs"].append({
                        "type": lt,
                        "date": date,
                        "file": log_file,
                        "path": f"/logs/content?type={lt}&date={date}&file={log_file}"
                    })
        
        return jsonify(result), 200
    
    except Exception as e:
        logger.error(f"Error listing logs: {str(e)}", exc_info=True)
        return jsonify({"error": str(e)}), 500

@app.route('/logs/content', methods=['GET'])
def get_log_content():
    # Проверка авторизации
    auth_header = request.headers.get('Authorization')
    if not auth_header or not auth_header.startswith('Bearer ') or auth_header[7:] != API_KEY:
        return jsonify({"error": "Unauthorized"}), 401
    
    try:
        log_type = request.args.get('type')
        date = request.args.get('date')
        file = request.args.get('file')
        
        if not all([log_type, date, file]):
            return jsonify({"error": "Missing required parameters: type, date, file"}), 400
        
        log_path = os.path.join(LOG_STORAGE_DIR, log_type, date, file)
        
        if not os.path.exists(log_path):
            return jsonify({"error": "Log file not found"}), 404
        
        with open(log_path, 'r') as f:
            content = json.load(f)
        
        return jsonify(content), 200
    
    except Exception as e:
        logger.error(f"Error getting log content: {str(e)}", exc_info=True)
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port) 