#!/bin/bash
# init_db.sh — Initialisation idempotente de MariaDB
# ====================================================
# Ce script :
# 1. Vérifie si la DB est déjà initialisée (volume persistant)
# 2. Si non → initialise MariaDB + crée la DB et l'utilisateur
# 3. Lance mysqld en foreground

set -e

# Si le datadir est vide, c'est le premier lancement
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "[init_db] Première initialisation de MariaDB..."

    # Initialiser le datadir
    mysql_install_db --user=mysql --datadir=/var/lib/mysql

    # Lancer MariaDB temporairement pour exécuter le SQL d'init
    mysqld --user=mysql &
    pid=$!

    # Attendre que MariaDB soit prêt
    echo "[init_db] Attente du démarrage de MariaDB..."
    for i in $(seq 1 30); do
        if mysqladmin ping --silent 2>/dev/null; then
            break
        fi
        sleep 1
    done

    # Exécuter le script d'initialisation
    echo "[init_db] Exécution du script SQL d'initialisation..."
    mysql < /etc/mysql/init.sql

    # Arrêter MariaDB proprement
    mysqladmin shutdown
    wait $pid

    echo "[init_db] Initialisation terminée."
else
    echo "[init_db] MariaDB déjà initialisée, démarrage normal."
fi

# Lancer MariaDB en foreground (CMD du Dockerfile)
exec "$@"
