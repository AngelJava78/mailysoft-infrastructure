# Instancia la base de datos del entorno (azure-existing o railway-managed, segun
# environment_provider), la red de Azure cuando aplica, y modules/service por cada entrada
# de services.tfvars. Anadir una API nueva = anadir una entrada a services.tfvars; este
# archivo no cambia por eso (FR-012 de 001-railway-deployment).

# FR-014 (002-single-provider-deployment): advertir, sin bloquear, cuando algun servicio se
# desvia del proveedor unico del entorno. Un check block es la herramienta correcta aqui
# (emite advertencia, nunca bloquea el apply) — a diferencia del bloqueo duro que si usa
# modules/service/aws para "proveedor no disponible" (variable validation, FR-005 de
# 001-railway-deployment).
check "provider_consistency" {
  assert {
    condition = length([
      for s in var.services : s.name
      if s.provider != null && s.provider != var.environment_provider
    ]) == 0
    error_message = "Servicios con provider distinto a environment_provider (\"${var.environment_provider}\"): ${join(", ", [for s in var.services : s.name if s.provider != null && s.provider != var.environment_provider])}. Confirmar explicitamente esta mezcla antes de aprobar el cambio (FR-014)."
  }
}

# ===== Base de datos del entorno (data-model.md, Entidad "Base de datos del entorno") =====
# La variante activa la decide unicamente environment_provider, nunca una variable
# independiente (contracts/database-module-interface.md, "Seleccion de variante"): evita que
# la base de datos quede expuesta al mismo escenario de mezcla de proveedores que FR-014
# advierte para el resto de los servicios.

locals {
  any_service_requires_database = anytrue([for s in var.services : s.requires_database])
}

module "mailysoft_db_azure" {
  source = "../../modules/database/azure-existing"
  count  = var.environment_provider == "azure" && local.any_service_requires_database ? 1 : 0

  resource_group_name = var.azure_resource_group_name
  server_name         = var.azure_db_server_name
  server_type         = var.azure_db_server_type
  database_name       = var.azure_db_database_name
  key_vault_id        = var.azure_key_vault_id
}

module "mailysoft_db_railway" {
  source = "../../modules/database/railway-managed"
  count  = var.environment_provider == "railway" && local.any_service_requires_database ? 1 : 0

  environment_name       = var.environment_name
  railway_project_id     = var.railway_project_id
  railway_environment_id = var.railway_environment_id
  database_name           = "mailysoft_${var.environment_name}"
  region                   = var.region_hint
}

locals {
  db_connection = (
    length(module.mailysoft_db_azure) > 0 ? {
      host       = module.mailysoft_db_azure[0].host
      port       = module.mailysoft_db_azure[0].port
      secret_ref = module.mailysoft_db_azure[0].connection_secret_value
      } : length(module.mailysoft_db_railway) > 0 ? {
      host       = module.mailysoft_db_railway[0].host
      port       = module.mailysoft_db_railway[0].port
      secret_ref = module.mailysoft_db_railway[0].connection_secret_value
    } : null
  )

  db_kind = (
    length(module.mailysoft_db_azure) > 0 ? module.mailysoft_db_azure[0].kind :
    length(module.mailysoft_db_railway) > 0 ? module.mailysoft_db_railway[0].kind :
    null
  )
}

# ===== Red de Azure (una sola vez por entorno; contracts/network-domain-interface.md) =====

module "azure_network" {
  source = "../../modules/network-domain/azure"
  count  = var.environment_provider == "azure" ? 1 : 0

  environment_name            = var.environment_name
  location                     = var.azure_location
  public_service_names         = [for s in var.services : s.name if s.enabled && s.domain_type == "public"]
  private_service_names        = [for s in var.services : s.name if s.enabled && s.domain_type != "public"]
  database_requires_isolation  = local.any_service_requires_database

  tags = {
    proyecto       = "mailysoft"
    servicio       = "red"
    entorno        = var.environment_name
    propietario    = "equipo-plataforma"
    gestionado_por = "terraform"
  }
}

locals {
  # FR-007 (002-single-provider-deployment): declarar la garantia de aislamiento activa.
  # El valor de Railway se conoce de antemano (research.md de 001 §4; no requiere
  # instanciar modules/network-domain/railway a nivel de entorno, porque ese modulo ya se
  # instancia una vez POR SERVICIO desde dentro de modules/service/railway).
  isolation_guarantee = var.environment_provider == "azure" ? module.azure_network[0].isolation_guarantee : "credenciales"
}

# ===== Servicios (data-model.md, Entidad Servicio) =====

module "service" {
  source   = "../../modules/service"
  for_each = { for s in var.services : s.name => s }

  name                   = each.value.name
  enabled                 = each.value.enabled
  provider_name           = coalesce(each.value.provider, var.environment_provider) # FR-001
  railway_project_id      = var.railway_project_id
  railway_environment_id  = var.railway_environment_id
  source_repo             = each.value.source_repo
  source_ref              = each.value.source_ref
  container_image         = each.value.container_image
  region                   = var.region_hint
  domain_type              = each.value.domain_type
  custom_domain            = each.value.custom_domain
  env_vars                 = each.value.env_vars
  secret_refs              = each.value.secret_refs
  resources                = each.value.resources

  azure_network = var.environment_provider == "azure" ? module.azure_network[0].compute_network_refs : null

  database_connection = each.value.requires_database ? local.db_connection : null

  tags = {
    proyecto       = "mailysoft"
    servicio       = each.value.servicio_tag
    entorno        = var.environment_name
    propietario    = each.value.propietario_tag
    gestionado_por = "terraform"
  }
}
