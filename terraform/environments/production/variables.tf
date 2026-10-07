variable "dns_label_prefix" {
  description = "Préfixe du label DNS (doit être unique dans la région Azure)."
  type        = string
}

variable "admin_ssh_public_key" {
  description = "Clé publique SSH de déploiement."
  type        = string
}
