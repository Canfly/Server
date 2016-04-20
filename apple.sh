#!/usr/bin/env bash

rm -r /etc/nginx
cp -r ~/server-config/nginx /etc
nginx -t
nginx -s reload