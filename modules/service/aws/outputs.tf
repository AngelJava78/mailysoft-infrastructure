output "service_id" {
  value       = null
  description = "Siempre null: este modulo nunca llega a crear un recurso (FR-005)."
}

output "public_url" {
  value       = null
  description = "Siempre null."
}

output "internal_address" {
  value       = null
  description = "Siempre null."
}

output "provider_available" {
  value       = false
  description = "Siempre false: el proveedor aws no esta operativo en esta fase (FR-005)."
}
