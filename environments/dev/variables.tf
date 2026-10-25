# Declaracion de las variables pobladas por environment.tfvars, database.tfvars y
# services.tfvars (Principio IV: configuracion sobre codigo; data-model.md).

variable "environment_name" {
  type        = string
  description = "Nombre del entorno (dev, staging o production)."

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment_name)
    error_message = "environment_name debe ser uno de: dev, staging, production (FR-003)."
  }
}

variable "railway_project_id" {
  type        = string
  description = "Id del proyecto Railway 'mailysoft' (salida de bootstrap/railway-project)."
}

variable "railway_environment_id" {
  type        = string
  description = "Id del Railway Environment de este entorno (salida de bootstrap/railway-project)."
}

variable "region_hint" {
  type        = string
  description = "Region de Railway mas cercana a la region de Azure donde vive mailysoft-db, de entre las que soportan los servicios requeridos (FR-017)."
}

variable "azure_resource_group_name" {
  type        = string
  description = "Resource group de Azure donde vive mailysoft-db."
}

variable "azure_db_server_name" {
  type        = string
  description = "Nombre del servidor PostgreSQL de Azure ya existente."
}

variable "azure_db_server_type" {
  type        = string
  description = "'flexible' o 'single' (modules/database/azure-existing)."
  default     = "flexible"
}

variable "azure_db_database_name" {
  type        = string
  description = "Base de datos logica dentro del servidor, distinta por entorno para aislar dev/staging de production."
}

variable "azure_key_vault_id" {
  type        = string
  description = "Id del Key Vault compartido (salida de bootstrap/azure-backend)."
}

variable "services" {
  description = "Lista de servicios de este entorno (data-model.md Entidad Servicio)."

  type = list(object({
    name              = string
    enabled           = bool
    provider          = string
    servicio_tag      = string
    propietario_tag   = string
    source_repo       = optional(string, "")
    source_ref        = optional(string, "main")
    domain_type       = optional(string, "private")
    custom_domain     = optional(string, "")
    env_vars          = optional(map(string), {})
    secret_refs       = optional(map(string), {})
    resources = optional(object({
      cpu       = optional(string)
      memory_mb = optional(number)
      replicas  = optional(number, 1)
    }), {})
    requires_database = optional(bool, false)
  }))

  validation {
    condition     = alltrue([for s in var.services : can(regex("^mailysoft-[a-z0-9-]+-${var.environment_name}$", s.name))])
    error_message = "Cada services[*].name debe seguir el formato mailysoft-<servicio>-${var.environment_name} (Principio VII)."
  }

  validation {
    condition     = alltrue([for s in var.services : contains(["railway", "azure", "aws"], s.provider)])
    error_message = "services[*].provider debe ser uno de: railway, azure, aws (FR-004)."
  }

  validation {
    condition     = length(distinct([for s in var.services : s.name])) == length(var.services)
    error_message = "services[*].name debe ser unico dentro del entorno (data-model.md)."
  }
}
