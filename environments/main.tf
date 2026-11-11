# Root 100% Railway (ADR 0005), compartido por los tres entornos de la plataforma (ADR 0007:
# un solo root parametrizado por var.environment_name, en vez de una copia por entorno).
# Instancia la base de datos (siempre railway-managed) y modules/service/railway directamente
# por cada entrada ENABLED de services.tfvars. Nunca llama al despachador generico
# modules/service ni a ningun modulo de Azure (ver providers.tf y
# docs/adr/0005-separar-roots-por-proveedor.md). El gate de aprobacion manual de production
# vive en el pipeline (FR-009), no en este codigo.

locals {
  any_service_requires_database = anytrue([for s in var.services : s.requires_database])
  enabled_services              = { for s in var.services : s.name => s if s.enabled }
}

module "mailysoft_db_railway" {
  source = "../modules/database/railway-managed"
  count  = local.any_service_requires_database ? 1 : 0

  environment_name       = var.environment_name
  railway_project_id     = var.railway_project_id
  railway_environment_id = var.railway_environment_id
  database_name          = "mailysoft_${var.environment_name}"
  region                 = var.region_hint
}

locals {
  db_connection = length(module.mailysoft_db_railway) > 0 ? {
    host       = module.mailysoft_db_railway[0].host
    port       = module.mailysoft_db_railway[0].port
    secret_ref = module.mailysoft_db_railway[0].connection_secret_value
  } : null

  db_kind = length(module.mailysoft_db_railway) > 0 ? module.mailysoft_db_railway[0].kind : null

  isolation_guarantee = "credenciales"
}

module "service" {
  source   = "../modules/service/railway"
  for_each = local.enabled_services

  name                   = each.value.name
  railway_project_id     = var.railway_project_id
  railway_environment_id = var.railway_environment_id
  source_repo            = each.value.source_repo
  source_ref             = each.value.source_ref
  region                 = var.region_hint
  domain_type            = each.value.domain_type
  custom_domain          = each.value.custom_domain
  env_vars               = each.value.env_vars
  secret_refs            = each.value.secret_refs
  resources              = each.value.resources

  database_connection = each.value.requires_database ? local.db_connection : null

  tags = {
    proyecto       = "mailysoft"
    servicio       = each.value.servicio_tag
    entorno        = var.environment_name
    propietario    = each.value.propietario_tag
    gestionado_por = "terraform"
  }
}
