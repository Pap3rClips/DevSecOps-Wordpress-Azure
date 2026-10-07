# Valeurs à reporter dans les variables GitHub (voir docs/setup.md).
# Aucune n'est un secret : ce sont des identifiants publics.

output "github_variables" {
  description = "Variables à créer dans GitHub (Settings > Secrets and variables > Actions)."
  value = {
    repository = {
      AZURE_TENANT_ID         = data.azurerm_client_config.current.tenant_id
      AZURE_SUBSCRIPTION_ID   = var.subscription_id
      TFSTATE_RESOURCE_GROUP  = azurerm_resource_group.tfstate.name
      TFSTATE_STORAGE_ACCOUNT = azurerm_storage_account.tfstate.name
    }
    environment_staging = {
      AZURE_CLIENT_ID = azuread_application.ci["staging"].client_id
    }
    environment_production_and_production_ops = {
      AZURE_CLIENT_ID = azuread_application.ci["production"].client_id
    }
  }
}
