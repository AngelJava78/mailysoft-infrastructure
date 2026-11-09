variable "name" {
  type        = string
  description = "Nombre completo del servicio (formato mailysoft-<servicio>-<entorno>)."
}

variable "enabled" {
  type        = bool
  description = "Si es false, el modulo no crea ningun recurso para este servicio (FR-002 de 001-railway-deployment)."
}

variable "source_repo" {
  type        = string
  description = "Referencia al repositorio de codigo fuente del microservicio. Solo se usa para derivar un valor por omision de container_image cuando este no se declara; nunca se construye desde aqui (Principio I)."
  default     = ""
}

variable "source_ref" {
  type        = string
  description = "Rama o tag del repositorio; se usa como tag de la imagen cuando container_image no se declara explicitamente."
  default     = "main"
}

variable "container_image" {
  type        = string
  description = "Referencia completa a la imagen de contenedor ya construida (ej. ghcr.io/mailysoft/mailysoft-usuarios-api:main). A diferencia de Railway (que construye nativamente desde source_repo via Nixpacks), Azure App Service/Container Apps MUST desplegar desde una imagen ya publicada por el pipeline del propio microservicio (Principio I: este repositorio nunca construye codigo de aplicacion). Si se omite, se deriva de source_repo/source_ref reemplazando 'github.com/' por 'ghcr.io/' — valido solo si el microservicio publica ahi con esa convencion; de lo contrario, declarar este campo explicitamente en services.tfvars."
  default     = ""
}

variable "domain_type" {
  type        = string
  description = "'public' (Azure App Service, endpoint publico nativo) o 'private' (Azure Container Apps, ingress interno, sin FQDN publico — FR-004 de 002-single-provider-deployment)."
  default     = "private"

  validation {
    condition     = contains(["public", "private"], var.domain_type)
    error_message = "domain_type debe ser 'public' o 'private'."
  }
}

variable "custom_domain" {
  type        = string
  description = "Dominio personalizado para servicios domain_type = public. Vacio = usar el dominio *.azurewebsites.net autogenerado por App Service."
  default     = ""
}

variable "env_vars" {
  type        = map(string)
  description = "Variables de entorno no sensibles del servicio."
  default     = {}
}

variable "secret_refs" {
  type        = map(string)
  description = "Secretos a inyectar como variables de entorno sensibles. Llegan ya resueltos (FR-011 de 001-railway-deployment)."
  default     = {}
  sensitive   = true
}

variable "resources" {
  type = object({
    cpu       = optional(string)
    memory_mb = optional(number)
    replicas  = optional(number, 1)
  })
  description = "Tamano y replicas del servicio. Si se omite un campo, se usa un valor por defecto razonable para App Service/Container Apps."
  default = {}
}

variable "database_connection" {
  type = object({
    host       = string
    port       = number
    secret_ref = string
  })
  description = "Dato de conexion a la base de datos del entorno (nunca un recurso administrado por este modulo). null si el servicio no requiere base de datos (FR-006)."
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
  description = "Las 5 etiquetas obligatorias del Principio VII; Azure las soporta como tags nativas."
}

variable "network" {
  type = object({
    resource_group_name           = string
    location                       = string
    subnet_id_web                  = string
    subnet_id_apis                 = string
    container_apps_environment_id  = string
  })
  description = "Salida compute_network_refs de modules/network-domain/azure (002-single-provider-deployment, contracts/network-domain-interface.md): donde colocar este servicio segun domain_type. Obligatorio cuando este modulo esta activo (provider_name = azure)."
}
