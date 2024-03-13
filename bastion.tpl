#!/bin/bash

# Capture and redirect
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>/home/${ssh_username}/setup_bastion.log 2>&1

# Everything below will go to the file 'setup_bastion.log':

# Print executed commands for debugging
set -x

wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update
sudo apt-get install -y vault mysql-server

# Set hostname because it's used for Consul
sudo hostnamectl set-hostname hashidemos-bastion
echo '127.0.1.1       hashidemos-bastion.unassigned-domain        hashidemos-bastion' | sudo tee -a /etc/hosts

# Configure environment
echo export VAULT_ADDR="${vault_addr}" | sudo tee -a /home/${ssh_username}/.bashrc
echo export VAULT_TOKEN="${vault_token}" | sudo tee -a /home/${ssh_username}/.bashrc
echo export VAULT_NAMESPACE=admin | sudo tee -a /home/${ssh_username}/.bashrc

export VAULT_ADDR="${vault_addr}" 
export VAULT_TOKEN="${vault_token}"
export VAULT_NAMESPACE=admin

vault secrets enable database

# Configure the database secrets engine to talk to MySQL
vault write database/config/rdsmysqldatabase \
    plugin_name=mysql-database-plugin \
    connection_url="{{username}}:{{password}}@tcp(${mysql_address})/" \
    allowed_roles="vault-demo-app","vault-demo-app-long" \
    username="${mysql_user}" \
    password="${mysql_password}"

# Rotate root password
#vault write  -force data_protection/database/rotate-root/wsmysqldatabase

# Create a role with a longer TTL
vault write database/roles/vault-demo-app-long \
    db_name=rdsmysqldatabase \
    creation_statements="CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}';GRANT ALL ON my_app.* TO '{{name}}'@'%';" \
    default_ttl="24h" \
    max_ttl="24h"

vault read database/creds/vault-demo-app-long