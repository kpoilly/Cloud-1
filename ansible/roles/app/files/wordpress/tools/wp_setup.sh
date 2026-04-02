#!/bin/bash
# wp_setup.sh — Installation idempotente de WordPress
# =====================================================

set -e

WP_PATH="/var/www/html"

# WP-CLI est déjà installé via le Dockerfile
# --- Télécharger WordPress (si pas déjà fait) ---
if [ ! -f "${WP_PATH}/wp-login.php" ]; then
    echo "[wp_setup] Téléchargement de WordPress..."
    mkdir -p ${WP_PATH}
    cd ${WP_PATH}
    wp core download --allow-root --path=${WP_PATH}
else
    echo "[wp_setup] WordPress déjà téléchargé."
fi

cd ${WP_PATH}

# --- Attendre que MariaDB soit prêt ---
echo "[wp_setup] Attente de MariaDB..."
for i in $(seq 1 30); do
    if mysqladmin ping -h mariadb -u ${SQL_USER} -p${SQL_PASSWORD} --silent 2>/dev/null; then
        echo "[wp_setup] MariaDB est prêt."
        break
    fi
    echo "[wp_setup] MariaDB pas encore prêt, tentative $i/30..."
    sleep 2
done

# --- Créer wp-config.php (si pas déjà fait) ---
if [ ! -f "${WP_PATH}/wp-config.php" ]; then
    echo "[wp_setup] Création de wp-config.php..."
    wp config create --allow-root \
        --dbname=${SQL_DATABASE} \
        --dbuser=${SQL_USER} \
        --dbpass=${SQL_PASSWORD} \
        --dbhost=mariadb:3306 \
        --path=${WP_PATH}
else
    echo "[wp_setup] wp-config.php déjà existant."
fi

# --- Installer WordPress (si pas déjà fait) ---
if ! wp core is-installed --allow-root --path=${WP_PATH} 2>/dev/null; then
    echo "[wp_setup] Installation de WordPress..."
    wp core install --allow-root \
        --url=${WP_URL} \
        --title="${WP_TITLE}" \
        --admin_user=${WP_ADMIN_USER} \
        --admin_password=${WP_ADMIN_PASSWORD} \
        --admin_email=${WP_ADMIN_EMAIL} \
        --path=${WP_PATH}
else
    echo "[wp_setup] WordPress déjà installé."
fi

# Permissions correctes pour le contenu
chown -R www-data:www-data ${WP_PATH}
chmod 755 -R ${WP_PATH}/wp-content

echo "[wp_setup] WordPress prêt."

# Lancer PHP-FPM en foreground (CMD du Dockerfile)
exec "$@"
