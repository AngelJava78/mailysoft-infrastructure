output "service_id" {
  value       = railway_service.this.id
  description = "Id del servicio creado en Railway."
}

output "public_url" {
  value       = module.network_domain.public_url
  description = "URL publica si domain_type = public; null en caso contrario."
}

output "internal_address" {
  value       = "${var.name}.railway.internal"
  description = "Direccion de red privada (Private Networking, activa por defecto en Railway)."
}
