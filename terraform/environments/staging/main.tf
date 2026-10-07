# Staging : éphémère. Créé au début du pipeline de déploiement, détruit à la
# fin, jamais exposé à Internet (seul le runner CI y accède, temporairement).

module "stack" {
  source = "../../modules/wordpress-stack"

  environment          = "staging"
  resource_group_name  = "rg-wpsec-staging"
  dns_label            = "${var.dns_label_prefix}-staging"
  admin_ssh_public_key = var.admin_ssh_public_key

  public_web_access       = false
  vm_size                 = "Standard_B2s"
  backup_replication_type = "LRS"
  backup_soft_delete_days = 1
}
