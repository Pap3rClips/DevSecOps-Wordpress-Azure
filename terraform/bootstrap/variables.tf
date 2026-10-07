variable "subscription_id" {
  description = "ID de l'abonnement Azure cible."
  type        = string
}

variable "github_repository" {
  description = "Dépôt GitHub autorisé à s'authentifier, au format owner/repo."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "Format attendu : owner/repo."
  }
}

variable "project" {
  description = "Préfixe court utilisé dans le nom des ressources (minuscules, sans tiret)."
  type        = string
  default     = "wpsec"

  validation {
    condition     = can(regex("^[a-z0-9]{3,8}$", var.project))
    error_message = "3 à 8 caractères alphanumériques minuscules."
  }
}

variable "location" {
  description = "Région Azure."
  type        = string
  default     = "francecentral"
}
