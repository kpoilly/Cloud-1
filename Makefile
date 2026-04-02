# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Makefile                                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: kpoilly <kpoilly@student.42.fr>            +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2024/05/15 13:32:57 by kpoilly           #+#    #+#              #
#    Updated: 2025/04/02 19:00:00 by kpoilly          ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

ANSIBLE_DIR	= ansible
PLAYBOOK	= $(ANSIBLE_DIR)/playbook.yml
INVENTORY	= $(ANSIBLE_DIR)/inventory/hosts.yml
VAULT_FILE	= $(ANSIBLE_DIR)/group_vars/all/vault.yml

# --- Déploiement complet ---
all: deploy

deploy:
	@echo "Deploying Cloud-1..."
	cd $(ANSIBLE_DIR) && ansible-playbook playbook.yml --ask-vault-pass

link:
	@echo "https://kpoilly.duckdns.org"
	@echo "https://kpoilly.duckdns.org/phpmyadmin"

# --- Déploiement par étape (tags Ansible) ---
setup:
	@echo "Setting up server (common + docker)..."
	cd $(ANSIBLE_DIR) && ansible-playbook playbook.yml --ask-vault-pass --tags setup

dns:
	@echo "Configuring DuckDNS..."
	cd $(ANSIBLE_DIR) && ansible-playbook playbook.yml --ask-vault-pass --tags duckdns

tls:
	@echo "Setting up TLS certificates..."
	cd $(ANSIBLE_DIR) && ansible-playbook playbook.yml --ask-vault-pass --tags tls

app:
	@echo "Deploying application..."
	cd $(ANSIBLE_DIR) && ansible-playbook playbook.yml --ask-vault-pass --tags app

# --- Vérifications ---
check:
	@echo "Running syntax check..."
	cd $(ANSIBLE_DIR) && ansible-playbook playbook.yml --syntax-check

dry-run:
	@echo "Running dry-run (no changes applied)..."
	cd $(ANSIBLE_DIR) && ansible-playbook playbook.yml --ask-vault-pass --check

ping:
	@echo "Testing SSH connectivity..."
	cd $(ANSIBLE_DIR) && ansible cloud_servers -m ping --ask-vault-pass

# --- Gestion du vault ---
vault-edit:
	cd $(ANSIBLE_DIR) && ansible-vault edit group_vars/all/vault.yml

vault-encrypt:
	cd $(ANSIBLE_DIR) && ansible-vault encrypt group_vars/all/vault.yml

vault-decrypt:
	cd $(ANSIBLE_DIR) && ansible-vault decrypt group_vars/all/vault.yml

# --- Nettoyage ---
clean:
	@echo "Stopping containers on remote server..."
	cd $(ANSIBLE_DIR) && ansible cloud_servers -m shell \
		-a "docker compose -f /opt/cloud1/docker-compose.yml down 2>/dev/null || true" \
		--ask-vault-pass

fclean: clean
	@echo "Removing all application data on remote server..."
	cd $(ANSIBLE_DIR) && ansible cloud_servers -m shell \
		-a "rm -rf /opt/cloud1 && docker system prune -af 2>/dev/null || true" \
		--ask-vault-pass

re: fclean deploy

.PHONY: all deploy setup dns tls app check dry-run ping \
		vault-edit vault-encrypt vault-decrypt clean fclean re
