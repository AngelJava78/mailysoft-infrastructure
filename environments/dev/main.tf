# Instancia modules/database/azure-existing una vez (si algun servicio lo requiere) y
# modules/service por cada entrada de services.tfvars. Anadir una API nueva = anadir una
# entrada a services.tfvars; este archivo no cambia (FR-012).

module "mailysoft_db" {
  source = "../../modules/database/azure-existing"
  count  = anytrue([for s in var.services : s.requires_database]) ? 1 : 0

  resource_group_name = var.azure_resource_group_name
  server_name         = var.azure_db_server_name
  server_type         = var.azure_db_server_type
  database_name       = var.azure_db_database_name
  key_vault_id        = var.azure_key_vault_id
}

module "service" {
  source   = "../../modules/service"
  for_each = { for s in var.services : s.name => s }

  name                   = each.value.name
  enabled                = each.value.enabled
  provider_name          = each.value.provider
  railway_project_id     = var.railway_project_id
  railway_environment_id = var.railway_environment_id
  source_repo            = each.value.source_repo
  source_ref              = each.value.source_ref
  region                   = var.region_hint
  domain_type              = each.value.domain_type
  custom_domain            = each.value.custom_domain
  env_vars                 = each.value.env_vars
  secret_refs              = each.value.secret_refs
  resources                = each.value.resources

  database_connection = each.value.requires_database && length(module.mailysoft_db) > 0 ? {
    host       = module.mailysoft_db[0].host
    port       = module.mailysoft_db[0].port
    secret_ref = module.mailysoft_db[0].connection_secret_value
  } : null

  tags = {
    proyecto       = "mailysoft"
    servicio       = each.value.servicio_tag
    entorno        = var.environment_name
    propietario    = each.value.propietario_tag
    gestionado_por = "terraform"
  }
}
