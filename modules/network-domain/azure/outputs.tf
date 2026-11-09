output "isolation_guarantee" {
  value       = "red"
  description = "Siempre \"red\": los NSG de subred-apis y subred-data rechazan en la red cualquier origen no autorizado hacia la base de datos (FR-005; contracts/network-domain-interface.md)."
}

output "compute_network_refs" {
  value = {
    resource_group_name            = azurerm_resource_group.this.name
    location                       = azurerm_resource_group.this.location
    subnet_id_web                  = azurerm_subnet.web.id
    subnet_id_apis                 = azurerm_subnet.apis.id
    container_apps_environment_id  = azurerm_container_app_environment.apis.id
  }
  description = "Ids que modules/service/azure necesita para colocar cada servicio en la subred correcta: subred-web para las dos aplicaciones publicas (integracion de VNet saliente), subred-apis/el Container Apps Environment compartido para las seis APIs (contracts/network-domain-interface.md)."
}

output "subnet_id_data" {
  value       = var.database_requires_isolation ? azurerm_subnet.data[0].id : null
  description = "Id de subred-data, para que modules/database/azure-existing (cuando se sirva via Private Endpoint) se coloque ahi. null si ningun servicio del entorno requiere base de datos."
}
