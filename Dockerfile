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

# Создаем скрипт запуска для динамического изменения порта
RUN echo '#!/bin/sh' > /start.sh && \
    echo 'sed -i -E "s/listen [0-9]+/listen $PORT/g" /etc/nginx/conf.d/default.conf' >> /start.sh && \
    echo 'if [ ! -z "$LOGS_USER" ] && [ ! -z "$LOGS_PASSWORD" ]; then' >> /start.sh && \
    echo '  echo "Setting up Basic Auth for logs access..."' >> /start.sh && \
    echo '  htpasswd -bc /etc/nginx/.htpasswd "$LOGS_USER" "$LOGS_PASSWORD"' >> /start.sh && \
    echo 'else' >> /start.sh && \
    echo '  echo "WARNING: LOGS_USER or LOGS_PASSWORD not set. Using default credentials."' >> /start.sh && \
    echo '  htpasswd -bc /etc/nginx/.htpasswd "admin" "admin"' >> /start.sh && \
    echo 'fi' >> /start.sh && \
    echo 'exec nginx -g "daemon off;"' >> /start.sh && \
    chmod +x /start.sh

# Открываем порт
EXPOSE 8080

# Запускаем скрипт при старте контейнера
CMD ["/start.sh"]