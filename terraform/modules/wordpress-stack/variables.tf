variable "project" {
  description = "Préfixe court des ressources."
  type        = string
  default     = "wpsec"
}

variable "environment" {
  description = "Nom de l'environnement (staging, production)."
  type        = string

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "Environnement attendu : staging ou production."
  }
}

variable "resource_group_name" {
  description = "Resource group existant, créé par le bootstrap."
  type        = string
}

variable "vnet_cidr" {
  description = "Plage d'adresses du réseau virtuel."
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_web_access" {
  description = "Ouvre 80/443 à Internet. true en production, false en staging."
  type        = bool
  default     = false
}

variable "admin_ssh_cidrs" {
  description = "CIDR autorisés en SSH de façon permanente. Vide par défaut : la CI ouvre un accès éphémère."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for c in var.admin_ssh_cidrs : !contains(["0.0.0.0/0", "*", "Internet"], c)])
    error_message = "SSH ouvert à tout Internet interdit."
  }
}

variable "dns_label" {
  description = "Label DNS de l'IP publique (unique dans la région)."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,61}[a-z0-9]$", var.dns_label))
    error_message = "Label DNS invalide (minuscules, chiffres, tirets)."
  }
}

variable "vm_size" {
  description = "Taille de la VM."
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Utilisateur d'administration de la VM."
  type        = string
  default     = "deploy"
}

variable "admin_ssh_public_key" {
  description = "Clé publique SSH de déploiement."
  type        = string
}

variable "backup_replication_type" {
  description = "Réplication du compte de stockage des sauvegardes (LRS, ZRS, GRS)."
  type        = string
  default     = "LRS"
}

variable "backup_soft_delete_days" {
  description = "Rétention des blobs supprimés (protection anti-suppression)."
  type        = number
  default     = 14
}

variable "tags" {
  description = "Tags additionnels."
  type        = map(string)
  default     = {}
}
