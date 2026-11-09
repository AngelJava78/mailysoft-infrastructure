output "service_id" {
  value = (
    length(azurerm_linux_web_app.this) > 0 ? azurerm_linux_web_app.this[0].id :
    length(azurerm_container_app.this) > 0 ? azurerm_container_app.this[0].id :
    null
  )
  description = "Id del azurerm_linux_web_app (domain_type = public) o azurerm_container_app (domain_type = private) creado. null si enabled = false."
}

output "public_url" {
  value       = length(azurerm_linux_web_app.this) > 0 ? "https://${azurerm_linux_web_app.this[0].default_hostname}" : null
  description = "URL publica de App Service si domain_type = public; null en caso contrario (FR-003/FR-004: las seis APIs nunca tienen una)."
}

output "internal_address" {
  value       = length(azurerm_container_app.this) > 0 ? azurerm_container_app.this[0].ingress[0].fqdn : null
  description = "FQDN interno del Container App (alcanzable solo dentro de subred-apis, FR-004); null si domain_type = public."
}

output "provider_available" {
  value       = true
  description = "Siempre true: a partir de esta fase, azure es un proveedor de computo operativo (FR-002 de 002-single-provider-deployment)."
}
