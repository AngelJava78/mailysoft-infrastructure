output "host" {
  value       = "${railway_service.postgres.name}.railway.internal"
  description = "Direccion de red privada del servicio de Postgres (Private Networking, activa por defecto en Railway — mismo patron que modules/service/railway)."
}

output "port" {
  value       = 5432
  description = "Puerto estandar de PostgreSQL."
}

output "database_name" {
  value       = var.database_name
  description = "Nombre de la base de datos dentro del servicio."
}

output "connection_secret_value" {
  value       = random_password.postgres.result
  description = "Credencial de conexion generada por este modulo (no leida de un secreto externo, a diferencia de azure-existing). Marcada sensible: nunca debe imprimirse en logs ni en el plan (FR-011 de 001-railway-deployment)."
  sensitive   = true
}

output "kind" {
  value       = "administrada"
  description = "Siempre \"administrada\": este modulo crea y administra su propia base de datos, distinta de mailysoft-db en Azure (FR-011/FR-012; contracts/database-module-interface.md)."
}
