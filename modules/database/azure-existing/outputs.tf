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
