FROM python:3.11-slim

WORKDIR /app

# Установка зависимостей
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Копирование исходного кода
COPY app.py .

# Создание директории для логов
RUN mkdir -p logs

# Переменные окружения
ENV PORT=5000
ENV LOG_STORAGE_DIR=/app/logs
ENV API_KEY=your-secret-api-key

# Открыть порт
EXPOSE $PORT

# Запуск сервера
CMD ["gunicorn", "--bind", "0.0.0.0:${PORT}", "app:app"] 