output "public_ip" {
  description = "Adresse IP publique de la VM."
  value       = azurerm_public_ip.vm.ip_address
}

output "fqdn" {
  description = "Nom de domaine de la VM."
  value       = azurerm_public_ip.vm.fqdn
}

output "admin_username" {
  description = "Utilisateur SSH."
  value       = azurerm_linux_virtual_machine.app.admin_username
}

output "resource_group_name" {
  description = "Resource group de l'environnement."
  value       = data.azurerm_resource_group.this.name
}

output "nsg_name" {
  description = "NSG du subnet applicatif (la CI y ajoute une règle SSH éphémère)."
  value       = azurerm_network_security_group.app.name
}

output "backup" {
  description = "Paramètres restic consommés par Ansible."
  sensitive   = true
  value = {
    storage_account = azurerm_storage_account.backup.name
    container       = azurerm_storage_container.restic.name
    sas_token       = trimprefix(data.azurerm_storage_account_blob_container_sas.restic.sas, "?")
    restic_password = random_password.restic.result
  }
}

output "app_secrets" {
  description = "Secrets applicatifs consommés par Ansible."
  sensitive   = true
  value = {
    db_root_password  = random_password.db_root.result
    db_password       = random_password.db_user.result
    wp_admin_password = random_password.wp_admin.result
    wp_salt_seed      = random_password.wp_salt_seed.result
  }
}
