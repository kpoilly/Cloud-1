# Cloud-1

Automated deployment of a WordPress infrastructure on a remote server using Ansible.

This project takes the Docker-based architecture from `Inception` (WordPress + MariaDB + Nginx) and deploys it on a cloud instance with full automation, TLS, and proper security practices.

## Architecture

```
Internet
   │
   ▼
┌──────────────────────────────────────────────────┐
│               Remote Server (Scaleway)            │
│               UFW: only 22, 80, 443 open          │
│                                                    │
│   ┌────────────────────────────────────────────┐  │
│   │           Docker Compose                    │  │
│   │                                             │  │
│   │  Nginx (:80/:443)                           │  │
│   │    ├── / ──────────► WordPress (PHP-FPM)    │  │
│   │    └── /phpmyadmin ► PHPMyAdmin             │  │
│   │                          │                  │  │
│   │                     MariaDB (:3306 internal) │  │
│   │                                             │  │
│   │  Volumes: wordpress_data, mariadb_data      │  │
│   └────────────────────────────────────────────┘  │
│                                                    │
│   Cron: DuckDNS update (5min), Certbot (12h)      │
└──────────────────────────────────────────────────┘
```

4 containers, each running a single process:
- **Nginx** — reverse proxy, TLS termination, HTTP-to-HTTPS redirect
- **WordPress** — PHP-FPM application server
- **MariaDB** — SQL database (exposed only on the internal Docker network)
- **PHPMyAdmin** — database administration interface

## Prerequisites

- A remote server with Ubuntu 20.04+ and SSH access
- Python 3 and pip installed locally
- An SSH key configured for the remote server
- A [DuckDNS](https://www.duckdns.org/) account with a registered subdomain

## Setup

### 1. Install Ansible

```bash
pip3 install --user ansible
```

### 2. Configure the inventory

Edit `ansible/inventory/hosts.yml` and set your server IP and SSH key path:

```yaml
scaleway1:
  ansible_host: <YOUR_SERVER_IP>
  ansible_ssh_private_key_file: ~/.ssh/id_rsa
```

### 3. Configure variables

Edit `ansible/group_vars/all/vars.yml` to set your domain name and non-sensitive config.

### 4. Set up secrets

Edit `ansible/group_vars/all/vault.yml` with your passwords and DuckDNS token, then encrypt it:

```bash
make vault-encrypt
```

To edit the vault later:
```bash
make vault-edit
```

## Usage

### Full deployment

```bash
make deploy
```

This runs the entire Ansible playbook which will:
1. Update and secure the server (packages, firewall)
2. Install Docker from the official repository
3. Configure DuckDNS to point to the server
4. Obtain a Let's Encrypt TLS certificate
5. Build and start all containers

### Step-by-step deployment

```bash
make setup    # Server hardening + Docker installation
make dns      # DuckDNS configuration
make tls      # TLS certificate
make app      # Application deployment
```

### Verification

```bash
make ping     # Test SSH connectivity to the server
make check    # Validate Ansible playbook syntax
make dry-run  # Simulate deployment without applying changes
```

### Cleanup

```bash
make clean    # Stop containers on remote server
make fclean   # Stop containers + remove all data
make re       # Full clean + redeploy
```

## Project structure

```
Cloud-1/
├── Makefile
├── ansible/
│   ├── ansible.cfg                 # Ansible configuration
│   ├── inventory/
│   │   └── hosts.yml               # Server inventory
│   ├── group_vars/all/
│   │   ├── vars.yml                # Public variables
│   │   └── vault.yml               # Encrypted secrets
│   ├── playbook.yml                # Main playbook
│   └── roles/
│       ├── common/                 # Server hardening, firewall
│       ├── docker/                 # Docker installation
│       ├── duckdns/                # DNS configuration
│       ├── tls/                    # Let's Encrypt certificates
│       └── app/                    # Application deployment
│           ├── files/              # Dockerfiles, static configs
│           └── templates/          # Jinja2 templates (.env, compose, nginx)
└── srcs/                           # Original Inception project (reference)
```

## Security

- All secrets are managed with Ansible Vault (AES-256 encrypted)
- No credentials are stored in plain text in the repository
- Firewall allows only SSH (22), HTTP (80), and HTTPS (443)
- Database is accessible only through the internal Docker network
- TLS certificates are obtained from Let's Encrypt and auto-renewed
- MariaDB user has privileges restricted to the WordPress database only

## Persistence

Data survives server reboots:
- Docker service is enabled at boot
- All containers use `restart: unless-stopped`
- WordPress files and database are stored on named Docker volumes backed by host directories

## Multi-server deployment

The Ansible inventory supports multiple hosts. To deploy on additional servers, add entries under `cloud_servers` in `ansible/inventory/hosts.yml`:

```yaml
cloud_servers:
  hosts:
    server1:
      ansible_host: 1.2.3.4
    server2:
      ansible_host: 5.6.7.8
```

Then `make deploy` will configure all servers in parallel.