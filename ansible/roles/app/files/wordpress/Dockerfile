FROM debian:bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    php php-fpm \
    php-mysql php-gd php-cli php-curl php-xml php-mbstring \
    mariadb-client \
    && rm -rf /var/lib/apt/lists/*

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
