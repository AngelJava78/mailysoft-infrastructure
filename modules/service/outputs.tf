output "service_id" {
  value       = local.active_service_id
  description = "Identificador del recurso creado en el proveedor (null si enabled = false)."
}

output "public_url" {
  value       = local.active_public_url
  description = "URL publica si domain_type = public; null en caso contrario."
}

output "internal_address" {
  value       = local.active_internal_address
  description = "Direccion de red privada del servicio (ej. <servicio>.railway.internal)."
}

output "provider_available" {
  value       = contains(["railway", "azure"], var.provider_name)
  description = "false si el proveedor seleccionado aun no esta operativo (FR-005 de 001-railway-deployment); railway y azure estan operativos desde 002-single-provider-deployment (FR-002), aws sigue sin estarlo."
}
