# -----------------------------------------------------------------------------
# Bootstrap : à exécuter UNE SEULE FOIS, en local, par un compte Owner de
# l'abonnement. Crée tout ce dont la CI a besoin pour fonctionner sans aucun
# secret Azure statique :
#   - le stockage du state Terraform (authentification Entra ID uniquement) ;
#   - un resource group par environnement ;
#   - une identité par environnement (app Entra ID + service principal) liée
#     à GitHub Actions par fédération OIDC ;
#   - des droits limités au strict nécessaire (moindre privilège).
# -----------------------------------------------------------------------------

data "azurerm_client_config" "current" {}

locals {
  environments = {
    staging = {
      # Seuls les jobs GitHub rattachés à l'environnement "staging" peuvent
      # obtenir un jeton pour cette identité.
      github_subjects = ["environment:staging"]
    }
    production = {
      # "production" : déploiement (approbation manuelle requise côté GitHub)
      # "production-ops" : tâches planifiées (test de restauration, rescan)
      github_subjects = ["environment:production", "environment:production-ops"]
    }
  }

  federated_credentials = merge([
    for env, cfg in local.environments : {
      for subject in cfg.github_subjects :
      "${env}/${subject}" => { env = env, subject = subject }
    }
  ]...)

  tags = {
    project    = var.project
    managed_by = "terraform-bootstrap"
  }
}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# --- State Terraform ----------------------------------------------------------

resource "azurerm_resource_group" "tfstate" {
  name     = "rg-${var.project}-tfstate"
  location = var.location
  tags     = local.tags
}

# Exception documentée (docs/adr/0002) : les runners GitHub hébergés n'ont pas
# d'adresse IP fixe, un pare-feu réseau bloquerait la CI. La protection repose
# sur l'identité : aucune clé d'accès, RBAC Entra ID par conteneur, TLS 1.2+.
#trivy:ignore:AZU-0012
resource "azurerm_storage_account" "tfstate" {
  name                     = "st${var.project}tf${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.tfstate.name
  location                 = azurerm_resource_group.tfstate.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  # Aucune clé d'accès : seule l'authentification Entra ID (RBAC) est acceptée.
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
  allow_nested_items_to_be_public = false
  https_traffic_only_enabled      = true

  blob_properties {
    # Historique du state : permet de revenir à une version précédente.
    versioning_enabled = true
    delete_retention_policy {
      days = 30
    }
    container_delete_retention_policy {
      days = 30
    }
  }

  tags = local.tags
}

# Un conteneur par environnement : l'identité de staging ne peut pas lire le
# state de production (qui contient des secrets).
resource "azurerm_storage_container" "tfstate" {
  for_each              = local.environments
  name                  = "tfstate-${each.key}"
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"
}

# --- Resource groups des environnements ---------------------------------------
# Créés ici (et non par la CI) pour que les identités de CI n'aient des droits
# que sur leur propre RG, jamais au niveau de l'abonnement.

resource "azurerm_resource_group" "env" {
  for_each = local.environments
  name     = "rg-${var.project}-${each.key}"
  location = var.location
  tags     = merge(local.tags, { environment = each.key })
}

# --- Identités de CI (OIDC, sans secret) --------------------------------------

resource "azuread_application" "ci" {
  for_each     = local.environments
  display_name = "gh-${var.project}-${each.key}"
  owners       = [data.azurerm_client_config.current.object_id]
}

resource "azuread_service_principal" "ci" {
  for_each  = local.environments
  client_id = azuread_application.ci[each.key].client_id
  owners    = [data.azurerm_client_config.current.object_id]
}

resource "azuread_application_federated_identity_credential" "github" {
  for_each       = local.federated_credentials
  application_id = azuread_application.ci[each.value.env].id
  display_name   = replace("github-${each.value.subject}", ":", "-")
  description    = "GitHub Actions ${var.github_repository} (${each.value.subject})"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_repository}:${each.value.subject}"
}

# Contributor limité au resource group de l'environnement.
resource "azurerm_role_assignment" "env_contributor" {
  for_each             = local.environments
  scope                = azurerm_resource_group.env[each.key].id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.ci[each.key].object_id
}

# Lecture/écriture limitée au conteneur de state de l'environnement.
resource "azurerm_role_assignment" "env_tfstate" {
  for_each             = local.environments
  scope                = "${azurerm_storage_account.tfstate.id}/blobServices/default/containers/${azurerm_storage_container.tfstate[each.key].name}"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.ci[each.key].object_id
}
