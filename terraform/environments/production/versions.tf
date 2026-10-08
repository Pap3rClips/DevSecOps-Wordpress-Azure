terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.8"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }

  # Configuration partielle : storage_account_name et resource_group_name sont
  # fournis par la CI via -backend-config (voir .github/workflows/cd.yml).
  # Authentification OIDC + Entra ID : aucune clé d'accès au stockage.
  backend "azurerm" {
    container_name   = "tfstate-production"
    key              = "production.tfstate"
    use_azuread_auth = true
    use_oidc         = true
  }
}

provider "azurerm" {
  features {}
  # L'identité de CI n'a pas de droits au niveau de l'abonnement : on désactive
  # l'enregistrement automatique des resource providers (fait au bootstrap).
  resource_provider_registrations = "none"
  use_oidc                        = true
}
