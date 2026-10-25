variable "name" {
  type        = string
  description = "Nombre del servicio (usado en el mensaje de error de esta fase)."
}

variable "fail_with_not_available_message" {
  type        = bool
  description = "Siempre true; existe solo para alojar la validacion que bloquea este modulo (FR-005)."
  default     = true

  validation {
    condition     = !var.fail_with_not_available_message
    error_message = "El proveedor \"aws\" no esta disponible aun para servicios de computo en esta fase. Esta fase solo soporta \"railway\". Ver specs/001-railway-deployment/spec.md (FR-005)."
  }
}
