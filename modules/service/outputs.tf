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
  value       = var.provider_name == "railway"
  description = "false si el proveedor seleccionado aun no esta operativo en esta fase (FR-005)."
}
