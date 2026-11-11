variable "service_id" {
  type        = string
  description = "Id del railway_service al que se le configura la red."
}

variable "subdomain" {
  type        = string
  description = "Subdominio para el dominio autogenerado de Railway (resultado: https://<subdomain>.up.railway.app). Confirmado 2026-11-10 contra un plan real: railway_service_domain exige este atributo explicitamente, no lo deriva solo."
}

variable "environment_id" {
  type        = string
  description = "Id del Railway Environment al que pertenece el servicio."
}

variable "domain_type" {
  type        = string
  description = "'public' habilita Public Networking (dominio autogenerado o personalizado); 'private' deja el servicio accesible solo via Private Networking (activo por defecto en Railway, sin recurso adicional)."

  validation {
    condition     = contains(["public", "private"], var.domain_type)
    error_message = "domain_type debe ser 'public' o 'private'."
  }
}

variable "custom_domain" {
  type        = string
  description = "Dominio personalizado (requiere registros CNAME + TXT en el DNS del dominio). Vacio = usar el dominio autogenerado *.up.railway.app cuando domain_type = public."
  default     = ""
}
