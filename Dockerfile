FROM nginx:alpine

# Копируем конфигурационные файлы
COPY nginx/conf.d /etc/nginx/conf.d
COPY nginx/nginx.conf /etc/nginx/nginx.conf

# Копируем содержимое
COPY app /usr/share/nginx/html

# Устанавливаем переменную для порта (Railway предоставляет PORT)
ENV PORT=8080

# Создаем скрипт запуска для динамического изменения порта
RUN echo '#!/bin/sh' > /start.sh && \
    echo 'sed -i -E "s/listen [0-9]+/listen $PORT/g" /etc/nginx/conf.d/default.conf' >> /start.sh && \
    echo 'exec nginx -g "daemon off;"' >> /start.sh && \
    chmod +x /start.sh

# Открываем порт
EXPOSE 8080

# Запускаем скрипт при старте контейнера
CMD ["/start.sh"] 