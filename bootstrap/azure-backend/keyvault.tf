# T008: Key Vault compartido. Terraform crea el VAULT y el CONTENEDOR del secreto; el VALOR
# real de la contrasena de mailysoft-db se fija aparte, en una unica accion de datos (nunca
# commiteada), documentada en docs/runbooks/bootstrap.md (FR-011, research.md seccion 2).

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "mailysoft" {
  name                = var.key_vault_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tenant_id           = var.azure_tenant_id

  sku_name                   = "standard"
  purge_protection_enabled   = true
  soft_delete_retention_days = 90
  enable_rbac_authorization  = true

  tags = {
    proyecto       = var.tags.proyecto
    servicio       = var.tags.servicio
    entorno        = "compartido"
    propietario    = var.tags.propietario
    gestionado-por = var.tags.gestionado_por
  }
}

# Quien ejecuta este bootstrap necesita poder escribir el valor del secreto una vez
# (fuera de Terraform, via `az keyvault secret set`); se le concede el rol minimo necesario
# para esa unica accion de datos, no para administrar el vault.
resource "azurerm_role_assignment" "bootstrap_operator_secrets" {
  scope                = azurerm_key_vault.mailysoft.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Contenedor del secreto: Terraform solo reserva el nombre/metadatos; el valor se fija
# despues, fuera de este apply, para que el valor real nunca pase por el plan ni el state
# en un commit (research.md seccion 2, FR-011).
resource "azurerm_key_vault_secret" "mailysoft_db_connection" {
  name         = "mailysoft-db-connection"
  value        = "PENDIENTE-fijar-con-az-keyvault-secret-set-ver-docs-runbooks-bootstrap.md"
  key_vault_id = azurerm_key_vault.mailysoft.id

  lifecycle {
    ignore_changes = [value]
  }

  depends_on = [azurerm_role_assignment.bootstrap_operator_secrets]
}
