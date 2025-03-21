FROM nginx:alpine

# Копируем конфигурационные файлы
COPY nginx/conf.d /etc/nginx/conf.d

# Устанавливаем переменную для порта (Railway предоставляет PORT)
ENV PORT=8080

# Создаем файл для динамической конфигурации порта
RUN echo "#!/bin/sh\n\
sed -i \"s/listen 80/listen \${PORT}/g\" /etc/nginx/conf.d/default.conf\n\
nginx -g 'daemon off;'" > /docker-entrypoint.d/40-railway-port.sh && \
chmod +x /docker-entrypoint.d/40-railway-port.sh

# Открываем порт
EXPOSE ${PORT} 