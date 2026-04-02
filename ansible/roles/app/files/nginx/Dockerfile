FROM debian:bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    && rm -rf /var/lib/apt/lists/*

# Copier la config Nginx
COPY ./conf/nginx.conf /etc/nginx/conf.d/default.conf

# S'assurer que les répertoires existent
RUN mkdir -p /var/run/nginx \
    && chmod 755 /var/www/html \
    && chown -R www-data:www-data /var/www/html

# Supprimer la config par défaut d'nginx qui entre en conflit
RUN rm -f /etc/nginx/sites-enabled/default

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]
