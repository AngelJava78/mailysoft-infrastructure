variable "name" {
  type        = string
  description = "Nombre completo del servicio (formato mailysoft-<servicio>-<entorno>)."
}

variable "railway_project_id" {
  type        = string
  description = "Id del proyecto Railway 'mailysoft' (bootstrap/railway-project)."
}

variable "railway_environment_id" {
  type        = string
  description = "Id del Railway Environment (dev/staging/production) al que pertenece el servicio."
}

variable "source_repo" {
  type        = string
  description = "Referencia al repositorio de codigo fuente del microservicio (solo se referencia, nunca se construye aqui)."
  default     = ""
}

variable "source_ref" {
  type        = string
  description = "Rama o tag del repositorio a desplegar."
  default     = "main"
}

variable "region" {
  type        = string
  description = "Identificador de region de Railway (ej. us-west2, us-east4), resuelto como la mas cercana a la region de Azure de mailysoft-db (FR-017, research.md). null = usar el default de Railway."
  default     = null
  nullable    = true
}

variable "domain_type" {
  type    = string
  default = "private"
}

variable "custom_domain" {
  type    = string
  default = ""
}

variable "env_vars" {
  type    = map(string)
  default = {}
}

variable "secret_refs" {
  type    = map(string)
  default = {}
}

variable "resources" {
  type = object({
    cpu       = optional(string)
    memory_mb = optional(number)
    replicas  = optional(number, 1)
  })
  default = {}
}

variable "database_connection" {
  type = object({
    host       = string
    port       = number
    secret_ref = string
  })
  default  = null
  nullable = true
}

variable "tags" {
  type = object({
    proyecto       = string
    servicio       = string
    entorno        = string
    propietario    = string
    gestionado_por = string
  })
}
