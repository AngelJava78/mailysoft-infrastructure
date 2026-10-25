variable "resource_group_name" {
  type        = string
  description = "Resource group de Azure donde ya vive mailysoft-db."
}

variable "server_name" {
  type        = string
  description = "Nombre del servidor PostgreSQL de Azure ya existente (mailysoft-db)."
}

variable "server_type" {
  type        = string
  description = "SKU de PostgreSQL de Azure donde vive el servidor existente: 'flexible' (azurerm_postgresql_flexible_server, recomendado) o 'single' (azurerm_postgresql_server, legado)."
  default     = "flexible"

  validation {
    condition     = contains(["flexible", "single"], var.server_type)
    error_message = "server_type debe ser 'flexible' o 'single'."
  }
}

variable "database_name" {
  type        = string
  description = "Nombre de la base de datos dentro del servidor (ej. 'mailysoft')."
  default     = "mailysoft"
}

variable "key_vault_id" {
  type        = string
  description = "Id del Azure Key Vault (bootstrap/azure-backend) que contiene el secreto de conexion."
}

variable "connection_secret_name" {
  type        = string
  description = "Nombre del secreto en Key Vault con la cadena de conexion / contrasena de mailysoft-db."
  default     = "mailysoft-db-connection"
}
