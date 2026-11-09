# research.md de 002-single-provider-deployment, seccion 1: dos tipos de recurso de Azure
# segun el rol del servicio. domain_type = "public" (maily-backoffice, maily-frontend) usa
# Azure App Service con su endpoint publico nativo; domain_type = "private" (las seis APIs)
# usa Azure Container Apps dentro del Container Apps Environment COMPARTIDO que crea
# modules/network-domain/azure (una sola vez por entorno, no uno por API — var.network).
#
# Este modulo deja de ser el stub de la Fase 1 (FR-005 de 001-railway-deployment ya no
# aplica a "azure": ver modules/service/aws para el patron de stub que SI sigue vigente para
# ese otro proveedor).

locals {
  # Azure no construye desde un repositorio (a diferencia de Railway via Nixpacks); MUST
  # desplegar desde una imagen ya publicada por el pipeline del propio microservicio
  # (Principio I). Si container_image no se declara, se deriva de source_repo/source_ref como
  # valor por omision razonable — ver variables.tf para la advertencia completa.
  resolved_image = var.container_image != "" ? var.container_image : (
    var.source_repo != "" ? "${replace(var.source_repo, "github.com/", "ghcr.io/")}:${var.source_ref}" : ""
  )

  resolved_tags = {
    proyecto       = var.tags.proyecto
    servicio       = var.tags.servicio
    entorno        = var.tags.entorno
    propietario    = var.tags.propietario
    gestionado_por = var.tags.gestionado_por
  }

  database_env_vars = var.database_connection != null ? {
    DATABASE_HOST     = var.database_connection.host
    DATABASE_PORT     = tostring(var.database_connection.port)
    DATABASE_PASSWORD = var.database_connection.secret_ref
  } : {}

  all_app_settings = merge(var.env_vars, var.secret_refs, local.database_env_vars)
}

# ===== domain_type = "public": Azure App Service =====

resource "azurerm_service_plan" "web" {
  count               = var.enabled && var.domain_type == "public" ? 1 : 0
  name                = "${var.name}-plan"
  resource_group_name = var.network.resource_group_name
  location            = var.network.location
  os_type             = "Linux"
  sku_name            = coalesce(var.resources.cpu, "B1") # SKU de App Service, no vCPUs; B1 = valor por defecto razonable (Assumptions)

  tags = local.resolved_tags
}

resource "azurerm_linux_web_app" "this" {
  count               = var.enabled && var.domain_type == "public" ? 1 : 0
  name                = var.name
  resource_group_name = var.network.resource_group_name
  location            = var.network.location
  service_plan_id     = azurerm_service_plan.web[0].id

  virtual_network_subnet_id = var.network.subnet_id_web # integracion de VNet de salida hacia subred-apis (research.md §1)

  site_config {
    container_registry_use_managed_identity = false # imagen publica en GHCR en esta fase; revisar si el registro pasa a ser privado

    application_stack {
      docker_image_name = local.resolved_image
    }
  }

  app_settings = local.all_app_settings

  identity {
    type = "SystemAssigned" # groundwork para Key Vault via Managed Identity (research.md §5); el cableado de permisos queda como seguimiento
  }

  tags = local.resolved_tags
}

# ===== domain_type = "private": Azure Container Apps, sin ingress externo (FR-004) =====

resource "azurerm_container_app" "this" {
  count                        = var.enabled && var.domain_type == "private" ? 1 : 0
  name                         = var.name
  resource_group_name          = var.network.resource_group_name
  container_app_environment_id = var.network.container_apps_environment_id
  revision_mode                = "Single"

  template {
    min_replicas = 1
    max_replicas = coalesce(var.resources.replicas, 1)

    container {
      name   = var.name
      image  = local.resolved_image
      # resources.cpu es un campo generico heredado del Principio IV (data-model.md): en
      # Container Apps representa vCPUs fraccionarias ("0.5", "1"); en el Service Plan de
      # arriba representa el nombre del SKU ("B1"). Quien declara el servicio en Azure MUST
      # usar la convencion correcta para cada rama.
      cpu    = var.resources.cpu != null ? tonumber(var.resources.cpu) : 0.5
      memory = "${coalesce(var.resources.memory_mb, 1024) / 1024}Gi"

      dynamic "env" {
        for_each = local.all_app_settings
        content {
          name  = env.key
          value = env.value
        }
      }
    }
  }

  ingress {
    external_enabled = false # FR-004: nunca expuesta a internet, solo alcanzable dentro de subred-apis
    target_port       = 8000 # convencion de los microservicios Python existentes (uvicorn); sobreescribir via resources si un servicio usa otro puerto
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  identity {
    type = "SystemAssigned"
  }

  tags = local.resolved_tags
}
