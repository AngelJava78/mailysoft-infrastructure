# research.md de 002-single-provider-deployment, seccion 2: una VNet por entorno con tres
# subredes (subred-web, subred-apis, subred-data) y dos Network Security Groups que imponen
# en la red, no solo por configuracion de aplicacion, que "solo las APIs llegan a la base"
# (FR-005). A diferencia de modules/network-domain/railway (que se instancia una vez POR
# SERVICIO, porque el dominio publico/privado de Railway es una propiedad del servicio), este
# modulo se instancia UNA SOLA VEZ POR ENTORNO desde environments/<entorno>/main.tf: la VNet,
# las subredes, los NSG y el Container Apps Environment son recursos compartidos por las ocho
# aplicaciones de ese entorno, no uno por servicio.

resource "azurerm_resource_group" "this" {
  name     = "mailysoft-red-${var.environment_name}"
  location = var.location

  tags = {
    proyecto       = var.tags.proyecto
    servicio       = var.tags.servicio
    entorno        = var.tags.entorno
    propietario    = var.tags.propietario
    gestionado_por = var.tags.gestionado_por
  }
}

resource "azurerm_virtual_network" "this" {
  name                = "mailysoft-vnet-${var.environment_name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [var.address_space]

  tags = azurerm_resource_group.this.tags
}

# subred-web: solo alojan aqui la integracion de VNet DE SALIDA de maily-backoffice y
# maily-frontend (modules/service/azure, rama App Service). Ningun NSG de esta subred
# restringe su propio trafico de entrada: lo que la aisla de la base de datos es que
# nsg-data (abajo) nunca la incluye como origen permitido.
resource "azurerm_subnet" "web" {
  name                 = "subred-web"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [cidrsubnet(var.address_space, 8, 0)]

  delegation {
    name = "app-service-delegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# subred-apis: aloja el Container Apps Environment compartido por las seis APIs
# (modules/service/azure, rama Container Apps). Ninguna de las seis obtiene FQDN publico por
# construccion (ingress interno, FR-004); nsg-apis solo permite entrada desde subred-web y
# desde si misma.
resource "azurerm_subnet" "apis" {
  name                 = "subred-apis"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [cidrsubnet(var.address_space, 8, 1)]

  delegation {
    name = "container-apps-delegation"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_network_security_group" "apis" {
  name                = "nsg-apis-${var.environment_name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  tags = azurerm_resource_group.this.tags
}

resource "azurerm_network_security_rule" "apis_allow_from_web" {
  name                        = "allow-subred-web"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = azurerm_subnet.web.address_prefixes[0]
  destination_address_prefix  = azurerm_subnet.apis.address_prefixes[0]
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.apis.name
}

resource "azurerm_network_security_rule" "apis_allow_between_apis" {
  name                        = "allow-entre-apis"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = azurerm_subnet.apis.address_prefixes[0]
  destination_address_prefix  = azurerm_subnet.apis.address_prefixes[0]
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.apis.name
}

# Denegacion explicita (en la practica redundante con el "deny all" implicito de Azure, pero
# documentada aqui a proposito: hace visible en el propio plan/state la intencion de FR-005,
# en vez de depender solo de un comportamiento implicito del proveedor).
resource "azurerm_network_security_rule" "apis_deny_rest" {
  name                        = "deny-todo-lo-demas"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.apis.name
}

resource "azurerm_subnet_network_security_group_association" "apis" {
  subnet_id                 = azurerm_subnet.apis.id
  network_security_group_id = azurerm_network_security_group.apis.id
}

# subred-data: aloja la base de datos del entorno (modules/database/azure-existing via
# Private Endpoint, o modules/database/railway-managed si el entorno elige Railway — en ese
# caso esta subred no se usa, pero igual se crea para que el entorno sea simetrico si cambia
# de proveedor). nsg-data solo permite entrada desde subred-apis: ni subred-web ni internet
# pueden alcanzar la base, aunque tuvieran sus credenciales (FR-005).
resource "azurerm_subnet" "data" {
  count                = var.database_requires_isolation ? 1 : 0
  name                 = "subred-data"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [cidrsubnet(var.address_space, 8, 2)]

  private_endpoint_network_policies = "Enabled"
}

resource "azurerm_network_security_group" "data" {
  count               = var.database_requires_isolation ? 1 : 0
  name                = "nsg-data-${var.environment_name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  tags = azurerm_resource_group.this.tags
}

resource "azurerm_network_security_rule" "data_allow_from_apis" {
  count                       = var.database_requires_isolation ? 1 : 0
  name                        = "allow-subred-apis"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefix       = azurerm_subnet.apis.address_prefixes[0]
  destination_address_prefix  = azurerm_subnet.data[0].address_prefixes[0]
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.data[0].name
}

resource "azurerm_network_security_rule" "data_deny_rest" {
  count                       = var.database_requires_isolation ? 1 : 0
  name                        = "deny-todo-lo-demas"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.data[0].name
}

resource "azurerm_subnet_network_security_group_association" "data" {
  count                      = var.database_requires_isolation ? 1 : 0
  subnet_id                  = azurerm_subnet.data[0].id
  network_security_group_id  = azurerm_network_security_group.data[0].id
}

# Container Apps Environment COMPARTIDO por las seis APIs (research.md §1): vive aqui, no en
# modules/service/azure, precisamente para que se cree una sola vez por entorno y no una vez
# por API.
resource "azurerm_container_app_environment" "apis" {
  name                       = "mailysoft-cae-${var.environment_name}"
  location                   = azurerm_resource_group.this.location
  resource_group_name        = azurerm_resource_group.this.name
  infrastructure_subnet_id   = azurerm_subnet.apis.id
  internal_load_balancer_enabled = true # sin IP publica de entrada para el Environment completo (FR-004)

  tags = azurerm_resource_group.this.tags
}
