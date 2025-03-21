FROM nginx:alpine

# Копируем конфигурационные файлы
COPY nginx/conf.d /etc/nginx/conf.d
COPY nginx/nginx.conf /etc/nginx/nginx.conf

# Копируем содержимое
COPY app /usr/share/nginx/html

# Устанавливаем переменную для порта (Railway предоставляет PORT)
ENV PORT=8080

# Установка необходимых пакетов и Filebeat
RUN apk add --no-cache curl ca-certificates bash && \
    mkdir -p /etc/filebeat /var/log/filebeat && \
    curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-8.11.3-linux-x86_64.tar.gz && \
    tar xzvf filebeat-8.11.3-linux-x86_64.tar.gz && \
    mv filebeat-8.11.3-linux-x86_64/filebeat /usr/local/bin/ && \
    rm -rf filebeat-8.11.3-linux-x86_64.tar.gz filebeat-8.11.3-linux-x86_64 && \
    chmod +x /usr/local/bin/filebeat

# Копирование конфигурации Filebeat
COPY filebeat/filebeat.yml /etc/filebeat/filebeat.yml
RUN chmod go-w /etc/filebeat/filebeat.yml

# Создаем скрипт запуска для динамического изменения порта
RUN echo '#!/bin/sh' > /start.sh && \
    echo 'sed -i -E "s/listen [0-9]+/listen $PORT/g" /etc/nginx/conf.d/default.conf' >> /start.sh && \
    echo 'if [ ! -z "$LOG_ENDPOINT" ] && [ ! -z "$LOG_API_KEY" ]; then' >> /start.sh && \
    echo '  echo "Starting Filebeat..."' >> /start.sh && \
    echo '  /usr/local/bin/filebeat -c /etc/filebeat/filebeat.yml &' >> /start.sh && \
    echo 'fi' >> /start.sh && \
    echo 'exec nginx -g "daemon off;"' >> /start.sh && \
    chmod +x /start.sh

# Открываем порт
EXPOSE 8080

# Запускаем скрипт при старте контейнера
CMD ["/start.sh"] 