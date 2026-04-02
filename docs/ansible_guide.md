# Comprendre Ansible — Guide Cloud-1

Ce document explique le fonctionnement d'Ansible tel qu'on l'utilise dans ce projet.

## Qu'est-ce qu'Ansible ?

Ansible est un outil d'automatisation de configuration de serveurs. Il permet de décrire dans des fichiers YAML l'état souhaité d'une machine distante, puis de l'y amener automatiquement via SSH.

Aucun agent n'est installé sur le serveur cible. Ansible se connecte en SSH, exécute des commandes, et se déconnecte. C'est ce qu'on appelle une architecture **agentless**.

## Déclaratif vs Impératif

Avec un script bash classique, on écrit des instructions étape par étape (impératif) :

```bash
apt install nginx
```

Avec Ansible, on décrit l'état final voulu (déclaratif) :

```yaml
- name: Ensure nginx is installed
  apt:
    name: nginx
    state: present
```

La conséquence directe : si nginx est déjà installé, Ansible ne fait rien. C'est le principe d'**idempotence** — on peut relancer le playbook autant de fois qu'on veut sans risquer de casser quoi que ce soit.

## Flux d'exécution

Quand on lance `ansible-playbook playbook.yml --ask-vault-pass`, voici ce qui se passe :

```
Machine locale                              Serveur distant
┌────────────────────┐                      ┌────────────────────┐
│                    │                      │                    │
│ 1. Lit ansible.cfg │                      │                    │
│    → trouve le     │                      │                    │
│    chemin de       │                      │                    │
│    l'inventaire    │                      │                    │
│                    │                      │                    │
│ 2. Lit hosts.yml   │                      │                    │
│    → trouve l'IP   │                      │                    │
│    du serveur      │                      │                    │
│                    │                      │                    │
│ 3. Lit vars.yml    │                      │                    │
│    + vault.yml     │                      │                    │
│    (déchiffré)     │                      │                    │
│                    │                      │                    │
│ 4. Connexion SSH ──│──────────────────────│──►                 │
│                    │                      │                    │
│ Pour chaque tâche: │                      │ 5. Reçoit un       │
│ envoie un module   │──────────────────────│──► module Python    │
│ Python temporaire  │                      │    temporaire      │
│                    │                      │                    │
│ 7. Reçoit le       │◄─────────────────────│──  6. Exécute le   │
│    résultat        │                      │    module, renvoie │
│    (ok/changed/    │                      │    le résultat,    │
│     failed)        │                      │    supprime le     │
│                    │                      │    module           │
│ 8. Passe à la      │                      │                    │
│    tâche suivante  │                      │                    │
└────────────────────┘                      └────────────────────┘
```

## Structure des fichiers

### ansible.cfg

Fichier de configuration locale. Ansible le lit automatiquement quand on se trouve dans le même répertoire.

```ini
[defaults]
inventory = inventory/hosts.yml    # Où trouver la liste des serveurs
host_key_checking = False          # Ne pas vérifier la clé SSH du serveur
remote_user = root                 # Utilisateur de connexion
```

On désactive `host_key_checking` parce que l'instance Scaleway est éphémère : à chaque recréation, sa clé SSH change. En production stable, on activerait cette vérification.

### inventory/hosts.yml

L'inventaire liste les machines cibles, organisées en groupes :

```yaml
all:
  children:
    cloud_servers:           # Nom du groupe
      hosts:
        scaleway1:           # Nom logique (arbitraire)
          ansible_host: 51.15.X.X    # IP réelle
```

Dans le playbook, on cible un groupe avec `hosts: cloud_servers`. Pour déployer sur plusieurs serveurs en parallèle, il suffit d'ajouter des entrées sous `hosts`.

### group_vars/all/vars.yml et vault.yml

Ansible charge automatiquement toutes les variables définies dans `group_vars/all/`. Deux fichiers :

- **vars.yml** : variables publiques (nom de domaine, noms de base de données). Versionné dans git.
- **vault.yml** : variables sensibles (mots de passe, tokens). Chiffré avec AES-256 via `ansible-vault`.

Toutes ces variables sont ensuite utilisables dans les tâches et les templates avec la syntaxe `{{ nom_variable }}`.

### playbook.yml

Le point d'entrée principal. Il définit quel groupe de serveurs cibler et dans quel ordre exécuter les rôles :

```yaml
- name: Deploy Cloud-1
  hosts: cloud_servers
  gather_facts: true       # Collecter des infos sur le serveur (OS, RAM, etc.)
  roles:
    - common               # S'exécute en premier
    - docker
    - duckdns
    - tls
    - app                  # S'exécute en dernier
```

Les rôles s'exécutent séquentiellement, de haut en bas. Si un rôle échoue, Ansible s'arrête.

L'option `gather_facts: true` collecte automatiquement des informations sur le serveur (version d'OS, architecture CPU, adresses réseau, etc.) qui sont ensuite utilisables comme variables. Par exemple, `{{ ansible_distribution_release }}` retourne `jammy` sur Ubuntu 22.04.

### Les rôles

Un rôle est un bloc de configuration autonome et réutilisable. Chaque rôle a cette structure :

```
roles/common/
├── tasks/
│   └── main.yml        # Tâches à exécuter (point d'entrée)
├── templates/           # Fichiers Jinja2 (variables remplacées au déploiement)
├── files/               # Fichiers statiques (copiés tels quels)
└── handlers/
    └── main.yml         # Actions déclenchées par "notify"
```

Ansible cherche automatiquement `tasks/main.yml` quand un rôle est référencé.

## Anatomie d'une tâche

Une tâche YAML a toujours deux composants :

```yaml
- name: Description humaine    # Label affiché dans la console (ne fait rien)
  apt:                          # Module Ansible (c'est lui qui agit)
    name: nginx                 # Paramètre du module
    state: present              # Paramètre du module
```

Le champ `name` est purement informatif. C'est le **module** en-dessous qui détermine l'action. Ansible est livré avec des centaines de modules, chacun spécialisé dans une tâche :

| Module | Action | Équivalent bash |
|--------|--------|-----------------|
| `apt` | Installer/supprimer des paquets | `apt install`, `apt remove` |
| `copy` | Copier un fichier sur le serveur | `scp` |
| `template` | Copier un fichier en remplaçant les `{{ variables }}` | `envsubst` + `scp` |
| `file` | Créer/supprimer fichiers et répertoires, modifier les permissions | `mkdir`, `chmod`, `rm` |
| `service` | Gérer les services systemd | `systemctl start/stop/enable` |
| `ufw` | Configurer le firewall | `ufw allow/deny` |
| `command` | Exécuter une commande | commande directe |
| `shell` | Exécuter via le shell (pipes, redirections) | `bash -c "..."` |
| `cron` | Gérer les tâches planifiées | `crontab -e` |
| `get_url` | Télécharger un fichier | `wget`, `curl` |
| `uri` | Effectuer une requête HTTP | `curl` |
| `apt_repository` | Ajouter un dépôt APT | ajout dans `sources.list.d/` |

### Paramètres spéciaux des tâches

```yaml
- name: Example task
  command: docker info
  register: result           # Sauvegarde la sortie dans la variable "result"
  changed_when: false        # Indique que cette commande ne modifie rien
  ignore_errors: true        # Continue même si la tâche échoue
  when: condition == true    # Exécute seulement si la condition est vraie
  notify: restart service    # Déclenche un handler si la tâche provoque un changement
  retries: 3                 # Nombre de tentatives en cas d'échec
  delay: 10                  # Secondes entre chaque tentative
  loop:                      # Répète la tâche pour chaque élément de la liste
    - item1
    - item2
```

### Templates Jinja2

Les fichiers `.j2` sont des templates où les expressions `{{ }}` sont remplacées par les valeurs des variables Ansible au moment du déploiement :

```
# Template (nginx.conf.j2)                    # Fichier généré
server_name {{ domain_name }};       →        server_name kpoilly.duckdns.org;
ssl_certificate /etc/letsencrypt/    →        ssl_certificate /etc/letsencrypt/
  live/{{ domain_name }}/...;                   live/kpoilly.duckdns.org/...;
```

Le module `template` fait cette substitution. Le module `copy` copie le fichier tel quel sans substitution.

### Handlers

Les handlers sont des tâches qui ne s'exécutent que lorsqu'elles sont déclenchées par un `notify` :

```yaml
# Dans tasks/main.yml
- name: Update config file
  template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
  notify: restart nginx       # Déclenche le handler seulement si le fichier a changé

# Dans handlers/main.yml
- name: restart nginx
  service:
    name: nginx
    state: restarted
```

Si le fichier n'a pas changé (le template produit le même contenu), le handler ne se déclenche pas. Cela évite des redémarrages de service inutiles.

### Tags

Les tags permettent d'exécuter seulement certains rôles :

```yaml
roles:
  - role: common
    tags: [common, setup]
  - role: docker
    tags: [docker, setup]
  - role: app
    tags: [app, deploy]
```

```bash
# Exécuter uniquement les rôles tagués "setup"
ansible-playbook playbook.yml --tags setup

# Exécuter tout SAUF le tag "tls"
ansible-playbook playbook.yml --skip-tags tls
```

## Sortie de la console

Lors de l'exécution, chaque tâche affiche un statut :

| Statut | Signification |
|--------|---------------|
| **ok** (vert) | L'état souhaité est déjà en place, aucune modification |
| **changed** (jaune) | Ansible a effectué une modification sur le serveur |
| **failed** (rouge) | La tâche a échoué |
| **skipping** (cyan) | La tâche a été ignorée (condition `when` non remplie) |

Au premier lancement, la majorité des tâches seront en `changed`. Au deuxième lancement, tout devrait être en `ok` — c'est la preuve que l'idempotence fonctionne.

## Nos rôles dans ce projet

| Rôle | Responsabilité | Modules principaux utilisés |
|------|---------------|----------------------------|
| **common** | Mise à jour système, installation des dépendances, configuration du firewall UFW | `apt`, `ufw`, `service` |
| **docker** | Installation de Docker CE depuis le dépôt officiel | `get_url`, `apt_repository`, `apt`, `service`, `command` |
| **duckdns** | Configuration du DNS dynamique avec DuckDNS | `file`, `template`, `command`, `cron` |
| **tls** | Obtention et renouvellement automatique des certificats Let's Encrypt | `apt`, `command`, `cron` |
| **app** | Déploiement des fichiers Docker, génération des configs, lancement des containers | `file`, `copy`, `template`, `command`, `uri` |

### Ordre d'exécution et dépendances :

```
common ──► docker ──► duckdns ──► tls ──► app
  │          │           │         │       │
  │          │           │         │       └─ docker compose up
  │          │           │         └─ certbot (nécessite le DNS configuré)
  │          │           └─ API DuckDNS (nécessite curl installé par common)
  │          └─ Docker CE (nécessite les dépôts APT configurés par common)
  └─ apt update, firewall, dépendances de base
```

Chaque rôle dépend des précédents, d'où l'importance de l'ordre dans le playbook.
