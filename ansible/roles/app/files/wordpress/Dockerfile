FROM debian:bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
    wget ca-certificates \
    php php-fpm \
    php-mysql php-gd php-cli php-curl php-xml php-mbstring \
    mariadb-client \
    && rm -rf /var/lib/apt/lists/*

# Télécharger WP-CLI pendant le build
RUN wget -q https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -O /usr/local/bin/wp \
    && chmod +x /usr/local/bin/wp

# Créer le répertoire pour le socket PHP-FPM
RUN mkdir -p /run/php

# Copier la config PHP-FPM
COPY ./conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf

# Copier le script d'installation WordPress
COPY ./tools/wp_setup.sh /usr/local/bin/wp_setup.sh
RUN chmod +x /usr/local/bin/wp_setup.sh

EXPOSE 9000

ENTRYPOINT ["wp_setup.sh"]
CMD ["php-fpm8.2", "-F"]
