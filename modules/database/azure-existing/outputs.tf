output "host" {
  value       = local.fqdn
  description = "FQDN del servidor PostgreSQL de Azure ya existente (mailysoft-db)."
}

output "port" {
  value       = 5432
  description = "Puerto estandar de PostgreSQL."
}

output "database_name" {
  value       = var.database_name
  description = "Nombre de la base de datos dentro del servidor."
}

output "connection_secret_value" {
  value       = data.azurerm_key_vault_secret.db_connection.value
  description = "Credencial de conexion leida desde Key Vault. Marcada sensible: nunca debe imprimirse en logs ni en el plan (FR-011)."
  sensitive   = true
}

output "kind" {
  value       = "referenciada"
  description = "Siempre \"referenciada\": este modulo solo declara data sources de lectura sobre mailysoft-db, nunca la crea ni la destruye (Principio II, FR-013 de 002-single-provider-deployment; contracts/database-module-interface.md). Sin cambio de comportamiento: este output no modifica ningun recurso existente."
}
