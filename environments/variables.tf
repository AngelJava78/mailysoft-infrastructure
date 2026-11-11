# Declaracion de las variables pobladas por <entorno>/environment.tfvars,
# <entorno>/database.tfvars y <entorno>/services.tfvars (Principio IV: configuracion sobre
# codigo; data-model.md). Un solo root compartido por los tres entornos (ADR 0007).

variable "environment_name" {
  type        = string
  description = "Nombre del entorno (dev, staging o production)."

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment_name)
    error_message = "environment_name debe ser uno de: dev, staging, production (FR-003)."
  }
}

variable "environment_provider" {
  type        = string
  description = "Proveedor de este entorno. ADR 0005: este directorio es un root 100% Railway — no declara el provider azurerm ni referencia ningun modulo de Azure, asi que aqui solo puede valer \"railway\". Pasar un entorno a Azure exige un root de Terraform distinto, no cambiar este valor."

  validation {
    condition     = var.environment_provider == "railway"
    error_message = "Este root (ADR 0005) es 100% Railway: environment_provider solo puede ser \"railway\" aqui. Para Azure hace falta un root de Terraform separado (ver docs/adr/0005-separar-roots-por-proveedor.md)."
  }
}

variable "railway_project_id" {
  type        = string
  description = "Id del proyecto Railway de este entorno (salida de bootstrap/railway-project; ADR 0006: un proyecto distinto por entorno)."
}

variable "railway_environment_id" {
  type        = string
  description = "Id del ambiente por defecto del proyecto Railway de este entorno (salida de bootstrap/railway-project)."
}

variable "region_hint" {
  type        = string
  description = "Region de Railway mas cercana a la region de Azure donde vive mailysoft-db, de entre las que soportan los servicios requeridos (FR-017)."
}

variable "services" {
  description = "Lista de servicios de este entorno (data-model.md Entidad Servicio)."

  type = list(object({
    name            = string
    enabled         = bool
    provider        = optional(string) # FR-001: si se omite, hereda environment_provider (ver check "provider_consistency" en main.tf)
    servicio_tag    = string
    propietario_tag = string
    source_repo     = optional(string, "")
    source_ref      = optional(string, "main")
    container_image = optional(string, "") # solo con efecto si el provider resuelto es azure; ver modules/service/azure/README.md
    domain_type     = optional(string, "private")
    custom_domain   = optional(string, "")
    env_vars        = optional(map(string), {})
    secret_refs     = optional(map(string), {})
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
    # ADR 0005: este root no tiene ningun modulo de Azure/AWS que pueda honrar un override a
    # otro provider (a diferencia de FR-014, que antes solo advertia); aqui es un bloqueo
    # duro, no una advertencia, porque "aceptar" el valor y desplegarlo igual en Railway seria
    # silenciosamente incorrecto.
    condition     = alltrue([for s in var.services : s.provider == null || s.provider == "railway"])
    error_message = "services[*].provider, cuando se declara explicitamente, solo puede ser \"railway\" en este root (ADR 0005) — no hay ningun modulo de Azure/AWS aqui que pueda honrar otro valor."
  }

  validation {
    condition     = length(distinct([for s in var.services : s.name])) == length(var.services)
    error_message = "services[*].name debe ser unico dentro del entorno (data-model.md)."
  }
}
