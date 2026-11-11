# FR-007 (002-single-provider-deployment): declarar en la previsualizacion, para este
# entorno, si el aislamiento entre las APIs y la base de datos lo garantiza la red o solo las
# credenciales. El pipeline lo imprime junto al resumen del plan
# (contracts/pipeline-contract-delta.md).

output "isolation_guarantee" {
  value       = local.isolation_guarantee
  description = "\"red\" (Azure, impuesto por NSG) o \"credenciales\" (Railway, sin mecanismo de red equivalente)."
}

output "database_kind" {
  value       = local.db_kind
  description = "\"referenciada\" (Azure, mailysoft-db ya existente) o \"administrada\" (Railway, base nueva de este entorno) — null si ningun servicio requiere base de datos."
}
