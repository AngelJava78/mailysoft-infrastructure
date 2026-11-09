# Identico a environments/dev/outputs.tf (002-single-provider-deployment, FR-007).

output "isolation_guarantee" {
  value       = local.isolation_guarantee
  description = "\"red\" (Azure, impuesto por NSG) o \"credenciales\" (Railway, sin mecanismo de red equivalente)."
}

output "database_kind" {
  value       = local.db_kind
  description = "\"referenciada\" (Azure, mailysoft-db ya existente) o \"administrada\" (Railway, base nueva de este entorno) — null si ningun servicio requiere base de datos."
}
