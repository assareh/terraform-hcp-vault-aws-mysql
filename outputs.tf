output "bastion_ip" {
  value = aws_instance.bastion.public_ip
}

output "bastion_ssh" {
  value = "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ${local.private_key_filename} -o IdentitiesOnly=yes ubuntu@${aws_instance.bastion.public_ip}"
}

output "ssh_key" {
  value = nonsensitive(tls_private_key.bastion_ssh_key.private_key_pem)
}

output "vault_local_bind" {
  value = "https://localhost:9090/ui/vault/auth?namespace=admin&with=token"
}

output "vault_private_endpoint_url" {
  value = hcp_vault_cluster.this.vault_private_endpoint_url
}

output "vault_ssh_tunnel" {
  value = "ssh -i ${local.private_key_filename} -o IdentitiesOnly=yes ubuntu@${aws_instance.bastion.public_ip} -L 9090:${trimprefix(hcp_vault_cluster.this.vault_private_endpoint_url, "https://")}"
}

output "vault_token" {
  value = nonsensitive(hcp_vault_cluster_admin_token.admin.token)
}

output "vault_version" {
  value = hcp_vault_cluster.this.vault_version
}

output "mysql-host" {
  value = aws_db_instance.vault-mysql.endpoint
}

output "mysql-connection-string" {
  value = "mysql -h ${aws_db_instance.vault-mysql.address} -P 3306 -u ${var.db_user} --password='${nonsensitive(random_password.password.result)}'"
}
