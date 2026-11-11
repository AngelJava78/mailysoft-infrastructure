variable "name" {
  type        = string
  description = "Nombre del servicio (usado en el mensaje de error de esta fase)."
}

variable "fail_with_not_available_message" {
  type        = bool
  description = "Siempre true; existe solo para alojar la validacion que bloquea este modulo (FR-005). Sin valor por omision a proposito: con un default, Terraform evalua esta validacion aunque este modulo tenga count = 0 (confirmado 2026-11-10 contra un plan real), bloqueando entornos que nunca seleccionan \"aws\". Al exigir que quien llama la pase explicitamente (modules/service/main.tf), la validacion solo corre cuando este modulo realmente se instancia."

  validation {
    condition     = !var.fail_with_not_available_message
    error_message = "El proveedor \"aws\" no esta disponible aun para servicios de computo en esta fase. Esta fase solo soporta \"railway\". Ver specs/001-railway-deployment/spec.md (FR-005)."
  }
}
