variable "name" {
  type        = string
  description = "Nombre completo del servicio, formato mailysoft-<servicio>-<entorno>."

  validation {
    condition     = can(regex("^mailysoft-[a-z0-9-]+-(dev|staging|production)$", var.name))
    error_message = "name debe seguir el formato mailysoft-<servicio>-<entorno>, en minusculas (Principio VII de la constitucion)."
  }
}

variable "enabled" {
  type        = bool
  description = "Si es false, el modulo no crea ningun recurso para este servicio (FR-002)."
}

variable "provider_name" {
  type        = string
  description = "Proveedor de destino: railway (operativo en esta fase), azure o aws (reservados, ver FR-005). Corresponde al campo 'provider' de data-model.md; se renombra aqui porque 'provider' es una palabra reservada en Terraform."

  validation {
    condition     = contains(["railway", "azure", "aws"], var.provider_name)
    error_message = "provider_name debe ser uno de: railway, azure, aws (Principio II: orden Railway -> Azure -> AWS)."
  }
}

variable "railway_project_id" {
  type        = string
  description = "Id del proyecto Railway 'mailysoft' (bootstrap/railway-project). Requerido cuando provider_name = railway."
  default     = null
  nullable    = true
}

variable "railway_environment_id" {
  type        = string
  description = "Id del Railway Environment (dev/staging/production). Requerido cuando provider_name = railway."
  default     = null
  nullable    = true
}

variable "source_repo" {
  type        = string
  description = "Referencia al repositorio de codigo fuente del microservicio (solo se referencia, nunca se construye aqui - Principio I)."
  default     = ""
}

variable "source_ref" {
  type        = string
  description = "Rama o tag del repositorio a desplegar."
  default     = "main"
}

variable "region" {
  type        = string
  description = "Region de destino (ej. Railway region), resuelta por el entorno como la mas cercana a la region de Azure de mailysoft-db (FR-017)."
  default     = null
  nullable    = true
}

variable "domain_type" {
  type        = string
  description = "Tipo de dominio: public (Railway Public Networking) o private (Railway Private Networking)."
  default     = "private"

  validation {
    condition     = contains(["public", "private"], var.domain_type)
    error_message = "domain_type debe ser 'public' o 'private'."
  }
}

variable "custom_domain" {
  type        = string
  description = "Dominio personalizado. Vacio = usar el dominio autogenerado de Railway cuando domain_type = public."
  default     = ""
}

variable "env_vars" {
  type        = map(string)
  description = "Variables de entorno no sensibles del servicio."
  default     = {}
}

variable "secret_refs" {
  type        = map(string)
  description = "Secretos a inyectar como variables de entorno sensibles. En esta capa ya llegan resueltos (valor real, marcado sensible), nunca como nombres de secreto sin resolver (FR-011)."
  default     = {}
  sensitive   = true
}

variable "resources" {
  type = object({
    cpu       = optional(string)
    memory_mb = optional(number)
    replicas  = optional(number, 1)
  })
  description = "Tamano y replicas del servicio. Si se omite un campo, se usa el valor por defecto del proveedor."
  default = {}
}

variable "database_connection" {
  type = object({
    host       = string
    port       = number
    secret_ref = string
  })
  description = "Dato de conexion a una base de datos externa ya existente (nunca un recurso administrado por este modulo - FR-006). null si el servicio no requiere base de datos."
  default     = null
  nullable    = true
  sensitive   = true
}

variable "tags" {
  type = object({
    proyecto       = string
    servicio       = string
    entorno        = string
    propietario    = string
    gestionado_por = string
  })
  description = "Las 5 etiquetas obligatorias del Principio VII de la constitucion."
}
