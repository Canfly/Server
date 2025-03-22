FROM nginx:alpine

# Копируем конфигурационные файлы
COPY nginx/conf.d /etc/nginx/conf.d
COPY nginx/nginx.conf /etc/nginx/nginx.conf

# Копируем содержимое
COPY app /usr/share/nginx/html

# Устанавливаем переменную для порта (Railway предоставляет PORT)
ENV PORT=8080

# Установка необходимых пакетов для htpasswd и envsubst
RUN apk add --no-cache apache2-utils gettext

# Убедимся, что директория для логов существует и имеет правильные права
RUN mkdir -p /var/log/nginx && \
    echo "This is a test access log entry" > /var/log/nginx/access.log && \
    echo "This is a test error log entry" > /var/log/nginx/error.log && \
    chmod -R 777 /var/log/nginx && \
    chmod 666 /var/log/nginx/access.log && \
    chmod 666 /var/log/nginx/error.log && \
    chown -R nginx:nginx /var/log/nginx && \
    # Добавим тестовый htpasswd файл для базовой аутентификации
    htpasswd -bc /etc/nginx/.htpasswd admin admin

# Создаем скрипт запуска для динамического изменения порта
RUN echo '#!/bin/sh' > /start.sh && \
    echo 'echo "=== DEBUG INFO START ==="' >> /start.sh && \
    echo 'echo "PORT: $PORT"' >> /start.sh && \
    echo 'echo "HOSTNAME: $(hostname)"' >> /start.sh && \
    echo 'echo "Validating config file syntax:"' >> /start.sh && \
    echo 'nginx -t' >> /start.sh && \
    echo 'echo "=== DEBUG INFO END ==="' >> /start.sh && \
    echo 'sed -i -E "s/listen [0-9]+/listen $PORT/g" /etc/nginx/conf.d/default.conf' >> /start.sh && \
    echo 'if [ ! -z "$LOGS_USER" ] && [ ! -z "$LOGS_PASSWORD" ]; then' >> /start.sh && \
    echo '  echo "Setting up Basic Auth with custom credentials: $LOGS_USER"' >> /start.sh && \
    echo '  htpasswd -bc /etc/nginx/.htpasswd "$LOGS_USER" "$LOGS_PASSWORD"' >> /start.sh && \
    echo 'else' >> /start.sh && \
    echo '  echo "Using default admin:admin credentials"' >> /start.sh && \
    echo '  htpasswd -bc /etc/nginx/.htpasswd admin admin' >> /start.sh && \
    echo 'fi' >> /start.sh && \
    echo 'mkdir -p /var/log/nginx' >> /start.sh && \
    echo 'if [ -L /var/log/nginx/access.log ]; then' >> /start.sh && \
    echo '  rm /var/log/nginx/access.log' >> /start.sh && \
    echo 'fi' >> /start.sh && \
    echo 'if [ -L /var/log/nginx/error.log ]; then' >> /start.sh && \
    echo '  rm /var/log/nginx/error.log' >> /start.sh && \
    echo 'fi' >> /start.sh && \
    echo 'echo "=== Creating log files ===" > /var/log/nginx/access.log' >> /start.sh && \
    echo 'echo "Server started at $(date)" >> /var/log/nginx/access.log' >> /start.sh && \
    echo 'echo "Test log entry" >> /var/log/nginx/access.log' >> /start.sh && \
    echo 'echo "=== Creating log files ===" > /var/log/nginx/error.log' >> /start.sh && \
    echo 'echo "Server started at $(date)" >> /var/log/nginx/error.log' >> /start.sh && \
    echo 'echo "Test error entry" >> /var/log/nginx/error.log' >> /start.sh && \
    echo 'chmod -R 777 /var/log/nginx' >> /start.sh && \
    echo 'chmod 666 /var/log/nginx/access.log' >> /start.sh && \
    echo 'chmod 666 /var/log/nginx/error.log' >> /start.sh && \
    echo 'chown -R nginx:nginx /var/log/nginx' >> /start.sh && \
    echo 'echo "Log files created:"' >> /start.sh && \
    echo 'ls -la /var/log/nginx/' >> /start.sh && \
    echo 'exec nginx -g "daemon off;"' >> /start.sh && \
    chmod +x /start.sh

# Открываем порт
EXPOSE 8080

# Запускаем скрипт при старте контейнера
CMD ["/start.sh"]