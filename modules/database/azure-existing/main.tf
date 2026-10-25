# INVARIANTE (FR-006, Principio II): este modulo SOLO declara `data` sources de lectura.
# Esta prohibido anadir aqui cualquier `resource` de escritura sobre mailysoft-db (crearla,
# modificarla o destruirla). La auditoria de esta regla es la tarea T045 del plan de
# implementacion.

data "azurerm_postgresql_flexible_server" "existing" {
  count               = var.server_type == "flexible" ? 1 : 0
  name                = var.server_name
  resource_group_name = var.resource_group_name
}

data "azurerm_postgresql_server" "existing" {
  count               = var.server_type == "single" ? 1 : 0
  name                = var.server_name
  resource_group_name = var.resource_group_name
}

data "azurerm_key_vault_secret" "db_connection" {
  name         = var.connection_secret_name
  key_vault_id = var.key_vault_id
}

locals {
  fqdn = var.server_type == "flexible" ? (
    length(data.azurerm_postgresql_flexible_server.existing) > 0 ? data.azurerm_postgresql_flexible_server.existing[0].fqdn : null
    ) : (
    length(data.azurerm_postgresql_server.existing) > 0 ? data.azurerm_postgresql_server.existing[0].fqdn : null
  )
}
