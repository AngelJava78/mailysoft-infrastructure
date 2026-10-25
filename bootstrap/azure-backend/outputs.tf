output "storage_account_name" {
  value       = azurerm_storage_account.tfstate.name
  description = "Nombre de la Storage Account de estado remoto; usarlo en environments/<entorno>/backend.tf."
}

output "resource_group_name" {
  value       = var.resource_group_name
  description = "Resource group de la infraestructura compartida del backend."
}

output "state_containers" {
  value       = [for c in azurerm_storage_container.tfstate : c.name]
  description = "Contenedores Blob de estado remoto creados, uno por entorno."
}

output "key_vault_id" {
  value       = azurerm_key_vault.mailysoft.id
  description = "Id del Key Vault; usarlo en modules/database/azure-existing."
}

output "key_vault_name" {
  value       = azurerm_key_vault.mailysoft.name
  description = "Nombre del Key Vault."
}

output "github_oidc_client_id" {
  value       = azuread_application.github_oidc.client_id
  description = "Client id de la aplicacion de Entra ID a configurar como AZURE_CLIENT_ID en cada GitHub Environment."
}

output "azure_tenant_id" {
  value       = var.azure_tenant_id
  description = "Tenant id a configurar como AZURE_TENANT_ID en cada GitHub Environment."
}

output "azure_subscription_id" {
  value       = var.azure_subscription_id
  description = "Subscription id a configurar como AZURE_SUBSCRIPTION_ID en cada GitHub Environment."
}
