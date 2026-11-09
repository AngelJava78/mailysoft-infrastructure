variable "environment_name" {
  type        = string
  description = "Nombre del entorno (dev, staging o production); se usa para nombrar la VNet y el resource group dedicados a los recursos de computo/red de Azure de este entorno."
}

variable "location" {
  type        = string
  description = "Region de Azure (ej. 'eastus') donde se crean el resource group, la VNet, el Container Apps Environment y el App Service de este entorno (002-single-provider-deployment, research.md §1-2). No tiene relacion con la region de mailysoft-db, que ya existe."
}

variable "public_service_names" {
  type        = list(string)
  description = "Nombres de los servicios con domain_type = \"public\" de este entorno (data-model.md, Entidad Red de aislamiento). Informativo en esta implementacion: determina el tamano esperado de 'subred-web', no crea un recurso por servicio."
  default     = []
}

variable "private_service_names" {
  type        = list(string)
  description = "Nombres de los servicios con domain_type = \"private\" de este entorno. Informativo: determina el tamano esperado de 'subred-apis'."
  default     = []
}

variable "database_requires_isolation" {
  type        = bool
  description = "Si es true, este modulo MUST crear la subred y el NSG de datos ('subred-data', 'nsg-data') que solo permiten entrada desde 'subred-apis' (FR-005). Si ningun servicio del entorno requiere base de datos, se omiten esos recursos."
  default     = true
}

variable "address_space" {
  type        = string
  description = "Bloque CIDR /16 de la VNet de este entorno. Las tres subredes se derivan de el (subred-web, subred-apis, subred-data, /24 cada una)."
  default     = "10.20.0.0/16"
}

variable "tags" {
  type = object({
    proyecto       = string
    servicio       = string
    entorno        = string
    propietario    = string
    gestionado_por = string
  })
  description = "Las 5 etiquetas obligatorias del Principio VII de la constitucion; Azure sí soporta tags nativas (a diferencia de Railway, research.md de 001 §5)."
}
