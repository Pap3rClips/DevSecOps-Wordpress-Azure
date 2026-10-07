# Production : persistante, exposée en HTTPS (Let's Encrypt).

module "stack" {
  source = "../../modules/wordpress-stack"

  environment          = "production"
  resource_group_name  = "rg-wpsec-production"
  dns_label            = var.dns_label_prefix
  admin_ssh_public_key = var.admin_ssh_public_key

  public_web_access       = true
  vm_size                 = "Standard_B2s"
  backup_replication_type = "ZRS"
  backup_soft_delete_days = 14
}
