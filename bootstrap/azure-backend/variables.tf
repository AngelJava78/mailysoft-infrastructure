variable "azure_subscription_id" {
  type        = string
  description = "Subscription de Azure donde ya vive mailysoft-db y donde se creara el backend de estado."
}

variable "azure_tenant_id" {
  type        = string
  description = "Tenant de Microsoft Entra ID usado para la federacion OIDC con GitHub Actions."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group donde se crea la infraestructura compartida del backend (Storage Account, Key Vault, App Registration). Puede ser el mismo resource group donde ya vive mailysoft-db o uno dedicado."
}

variable "location" {
  type        = string
  description = "Region de Azure para la Storage Account y el Key Vault del backend."
}

variable "storage_account_name" {
  type        = string
  description = "Nombre (globalmente unico) de la Storage Account que alojara el estado remoto de Terraform."

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "storage_account_name debe tener entre 3 y 24 caracteres alfanumericos en minusculas (restriccion de Azure Storage)."
  }
}

variable "key_vault_name" {
  type        = string
  description = "Nombre del Azure Key Vault que alojara el secreto de conexion de mailysoft-db y otros secretos de la plataforma."
}

variable "github_repository" {
  type        = string
  description = "Repositorio de GitHub en formato 'owner/repo' autorizado a usar la federacion OIDC (ej. AngelJava78/mailysoft-infrastructure)."
}

variable "state_containers" {
  type        = list(string)
  description = "Contenedores Blob de estado remoto, uno por entorno (Principio III: estado separado por entorno)."
  default     = ["tfstate-dev", "tfstate-staging", "tfstate-production"]
}

variable "tags" {
  type = object({
    proyecto       = string
    servicio       = string
    propietario    = string
    gestionado_por = string
  })
  description = "Etiquetas obligatorias (Principio VII), sin el campo 'entorno' porque esta infraestructura es compartida por los tres entornos."
  default = {
    proyecto       = "mailysoft"
    servicio       = "infraestructura-compartida"
    propietario    = "plataforma-mailysoft"
    gestionado_por = "terraform"
  }
}
