# T006: backend de estado remoto (Storage Account + un contenedor Blob por entorno).
# Ejecucion unica, documentada en docs/runbooks/bootstrap.md. Tras aplicarse, cada
# environments/<entorno>/backend.tf referencia estos mismos nombres.

resource "azurerm_storage_account" "tfstate" {
  name                = var.storage_account_name
  resource_group_name = var.resource_group_name
  location            = var.location

  account_tier             = "Standard"
  account_replication_type = "GRS"
  account_kind             = "StorageV2"

  min_tls_version = "TLS1_2"

  blob_properties {
    versioning_enabled = true
  }

  # Cifrado en reposo: habilitado por defecto en toda Storage Account de Azure con claves
  # administradas por Microsoft (satisface el requisito de cifrado del Principio III sin
  # configuracion adicional en esta fase).

  tags = {
    proyecto       = var.tags.proyecto
    servicio       = var.tags.servicio
    entorno        = "compartido"
    propietario    = var.tags.propietario
    gestionado-por = var.tags.gestionado_por
  }
}

resource "azurerm_storage_container" "tfstate" {
  for_each = toset(var.state_containers)

  name               = each.value
  storage_account_id = azurerm_storage_account.tfstate.id
  # NOTA: azurerm >= 4.x reemplazo storage_account_name por storage_account_id en este
  # recurso; verificar contra la version exacta pinneada en versions.tf antes del primer apply.
  container_access_type = "private"
}
