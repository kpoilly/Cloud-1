# Commandes Makefile — Référence

Ce document détaille chaque commande disponible dans le Makefile, ce qu'elle fait concrètement, et quand l'utiliser.

## Déploiement

### `make deploy` (ou `make` / `make all`)

```bash
cd ansible && ansible-playbook playbook.yml --ask-vault-pass
```

Exécute le playbook complet. C'est la commande principale du projet. Elle lance tous les rôles dans l'ordre : common, docker, duckdns, tls, app.

`--ask-vault-pass` demande le mot de passe du vault pour déchiffrer les secrets au runtime. Le mot de passe n'est jamais stocké, il reste uniquement en mémoire le temps de l'exécution.

Quand l'utiliser : premier déploiement, ou pour s'assurer que tout est à jour.

---

### `make setup`

```bash
cd ansible && ansible-playbook playbook.yml --ask-vault-pass --tags setup
```

Exécute uniquement les rôles tagués `setup` : **common** et **docker**. Cela met à jour le serveur, configure le firewall, et installe Docker.

`--tags setup` filtre les rôles à exécuter. Dans le playbook, les rôles `common` et `docker` portent le tag `setup`.

Quand l'utiliser : pour préparer un serveur sans encore déployer l'application.

---

### `make dns`

```bash
cd ansible && ansible-playbook playbook.yml --ask-vault-pass --tags duckdns
```

Exécute uniquement le rôle **duckdns** : crée le script de mise à jour DNS, l'exécute une première fois, et configure le cron.

Quand l'utiliser : après avoir créé le compte DuckDNS, ou si le DNS ne pointe plus vers la bonne IP.

---

### `make tls`

```bash
cd ansible && ansible-playbook playbook.yml --ask-vault-pass --tags tls
```

Exécute uniquement le rôle **tls** : installe certbot et obtient un certificat Let's Encrypt.

Prérequis : le DNS doit déjà pointer vers le serveur (make dns), sinon le challenge HTTP-01 de Let's Encrypt échouera.

Quand l'utiliser : pour renouveler manuellement le certificat ou le reconfigurer.

---

### `make app`

```bash
cd ansible && ansible-playbook playbook.yml --ask-vault-pass --tags app
```

Exécute uniquement le rôle **app** : copie les fichiers Docker, génère les configs depuis les templates, et lance `docker compose up -d --build`.

Quand l'utiliser : après avoir modifié un Dockerfile, une config nginx, ou un template, sans avoir besoin de relancer toute la chaîne.

---

## Vérification

### `make ping`

```bash
cd ansible && ansible cloud_servers -m ping --ask-vault-pass
```

Teste la connectivité SSH avec le serveur. Ansible envoie un module `ping` (ce n'est pas un ICMP ping réseau, c'est un test de connexion SSH + exécution Python). Le flag `--ask-vault-pass` est nécessaire car Ansible charge automatiquement les fichiers de variables (`group_vars/all/vault.yml`), même pour un simple ping.

Réponse attendue :
```
scaleway1 | SUCCESS => {
    "ping": "pong"
}
```

Si ça échoue, les causes possibles sont : mauvaise IP dans l'inventaire, clé SSH incorrecte, serveur éteint, ou port 22 bloqué.

Quand l'utiliser : avant un déploiement, pour vérifier que le serveur est joignable.

---

### `make check`

```bash
cd ansible && ansible-playbook playbook.yml --syntax-check
```

Vérifie la syntaxe YAML de tout le playbook et de tous les rôles, sans se connecter au serveur et sans exécuter quoi que ce soit. Utile pour détecter des erreurs d'indentation ou de structure.

Quand l'utiliser : après avoir modifié un fichier YAML.

---

### `make dry-run`

```bash
cd ansible && ansible-playbook playbook.yml --ask-vault-pass --check
```

Le flag `--check` active le mode "dry-run" : Ansible se connecte au serveur et simule l'exécution de chaque tâche sans rien modifier. Il affiche ce qu'il ferait (ok / changed) sans le faire.

Certaines tâches (comme `command` et `shell`) ne peuvent pas être simulées et seront marquées comme `skipped`.

Quand l'utiliser : avant un vrai déploiement, pour visualiser les changements qui seront appliqués.

---

## Gestion du vault

### `make vault-encrypt`

```bash
cd ansible && ansible-vault encrypt group_vars/all/vault.yml
```

Chiffre le fichier vault avec AES-256. Demande un mot de passe qui servira ensuite à chaque `--ask-vault-pass`.

Le fichier chiffré ressemble à ça :
```
$ANSIBLE_VAULT;1.1;AES256
63626438643539303265613437613032316431...
```

Quand l'utiliser : après avoir créé ou modifié le vault en clair.

---

### `make vault-edit`

```bash
cd ansible && ansible-vault edit group_vars/all/vault.yml
```

Ouvre le vault dans l'éditeur par défaut ($EDITOR, souvent vim ou nano) en le déchiffrant temporairement en mémoire. Une fois l'éditeur fermé, le fichier est automatiquement re-chiffré sur disque.

Le fichier en clair n'est jamais écrit sur le disque, ce qui est plus sûr que de faire decrypt puis encrypt manuellement.

Quand l'utiliser : pour modifier un mot de passe ou un token.

---

### `make vault-decrypt`

```bash
cd ansible && ansible-vault decrypt group_vars/all/vault.yml
```

Déchiffre le vault et le laisse en clair sur le disque. A utiliser avec précaution car le fichier devient lisible par tous.

Ne pas oublier de re-chiffrer avec `make vault-encrypt` après modification, et ne surtout pas commit le fichier en clair.

Quand l'utiliser : si vault-edit pose problème, en dernier recours.

---

## Nettoyage

### `make clean`

```bash
cd ansible && ansible cloud_servers -m shell \
    -a "docker compose -f /opt/cloud1/docker-compose.yml down 2>/dev/null || true" \
    --ask-vault-pass
```

Cette commande utilise Ansible en mode "ad-hoc" (sans playbook) pour exécuter une commande directement sur le serveur. Le flag `-m shell` spécifie le module, `-a` fournit l'argument (la commande à exécuter).

`docker compose down` arrête et supprime les containers, mais préserve les volumes de données.

Le `2>/dev/null || true` évite une erreur si docker compose n'est pas installé ou si le fichier n'existe pas.

Quand l'utiliser : pour arrêter l'application sans perdre les données.

---

### `make fclean`

Exécute `make clean` puis supprime le répertoire `/opt/cloud1` et purge toutes les images Docker avec `docker system prune -af`.

Les données (articles WordPress, base de données) seront perdues.

Quand l'utiliser : pour repartir de zéro sur le serveur.

---

### `make re`

Enchaîne `make fclean` puis `make deploy`. Nettoyage complet suivi d'un redéploiement from scratch.

Quand l'utiliser : après des modifications majeures quand on veut un environnement propre.
