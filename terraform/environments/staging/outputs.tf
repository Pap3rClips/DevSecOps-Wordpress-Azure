output "public_ip" {
  value = module.stack.public_ip
}

output "fqdn" {
  value = module.stack.fqdn
}

output "admin_username" {
  value = module.stack.admin_username
}

output "resource_group_name" {
  value = module.stack.resource_group_name
}

output "nsg_name" {
  value = module.stack.nsg_name
}

output "backup" {
  value     = module.stack.backup
  sensitive = true
}

output "app_secrets" {
  value     = module.stack.app_secrets
  sensitive = true
}
