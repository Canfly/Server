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
    chmod 755 /var/log/nginx && \
    chmod 644 /var/log/nginx/access.log && \
    chmod 644 /var/log/nginx/error.log && \
    chown -R nginx:nginx /var/log/nginx && \
    # Добавим тестовый htpasswd файл для базовой аутентификации
    htpasswd -bc /etc/nginx/.htpasswd admin admin

# Создаем скрипт запуска для динамического изменения порта
RUN echo '#!/bin/sh' > /start.sh && \
    echo 'echo "=== DEBUG INFO START ==="' >> /start.sh && \
    echo 'echo "PORT: $PORT"' >> /start.sh && \
    echo 'echo "HOSTNAME: $(hostname)"' >> /start.sh && \
    echo 'echo "LOGS_USER: $LOGS_USER"' >> /start.sh && \
    echo 'echo "Listing /etc/nginx:"' >> /start.sh && \
    echo 'ls -la /etc/nginx/' >> /start.sh && \
    echo 'echo "Listing conf.d:"' >> /start.sh && \
    echo 'ls -la /etc/nginx/conf.d/' >> /start.sh && \
    echo 'echo "Content of default.conf:"' >> /start.sh && \
    echo 'cat /etc/nginx/conf.d/default.conf' >> /start.sh && \
    echo 'echo "=== DEBUG INFO END ==="' >> /start.sh && \
    echo 'sed -i -E "s/listen [0-9]+/listen $PORT/g" /etc/nginx/conf.d/default.conf' >> /start.sh && \
    echo 'echo "Creating htpasswd file with default admin:admin credentials..."' >> /start.sh && \
    echo 'htpasswd -bc /etc/nginx/.htpasswd admin admin' >> /start.sh && \
    echo 'if [ ! -z "$LOGS_USER" ] && [ ! -z "$LOGS_PASSWORD" ]; then' >> /start.sh && \
    echo '  echo "Setting up Basic Auth with custom credentials: $LOGS_USER"' >> /start.sh && \
    echo '  htpasswd -bc /etc/nginx/.htpasswd "$LOGS_USER" "$LOGS_PASSWORD"' >> /start.sh && \
    echo '  echo "Basic Auth credentials updated."' >> /start.sh && \
    echo 'else' >> /start.sh && \
    echo '  echo "WARNING: LOGS_USER or LOGS_PASSWORD not set. Using default admin:admin."' >> /start.sh && \
    echo 'fi' >> /start.sh && \
    echo 'echo "Created auth file: $(ls -la /etc/nginx/.htpasswd)"' >> /start.sh && \
    echo 'echo "Content of auth file: $(cat /etc/nginx/.htpasswd)"' >> /start.sh && \
    echo 'exec nginx -g "daemon off;"' >> /start.sh && \
    chmod +x /start.sh

# Открываем порт
EXPOSE 8080

# Запускаем скрипт при старте контейнера
CMD ["/start.sh"]