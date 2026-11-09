output "public_url" {
  value       = local.resolved_public_url
  description = "URL publica resuelta si domain_type = public; null en caso contrario."
}

output "isolation_guarantee" {
  value       = "credenciales"
  description = "Siempre \"credenciales\": Railway no ofrece un mecanismo de reglas de red entre servicios de un mismo entorno (research.md de 001-railway-deployment §4); la unica garantia disponible es a quien se le entregan las credenciales de conexion (002-single-provider-deployment, FR-006/FR-007; contracts/network-domain-interface.md). Sin cambio de comportamiento: este output no modifica ningun recurso existente."
}
