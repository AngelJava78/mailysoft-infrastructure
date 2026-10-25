# ADVERTENCIA (research.md seccion 1): terraform-community-providers/railway es un provider
# NO oficial; no se pudo confirmar contra el registro los nombres exactos de recursos y
# atributos durante la redaccion de este modulo. Verificar contra
# registry.terraform.io/providers/terraform-community-providers/railway/latest antes del
# primer `terraform init` real (ver docs/adr/0001-railway-terraform-community-provider.md).

resource "railway_service" "this" {
  project_id     = var.railway_project_id
  environment_id = var.railway_environment_id
  name           = var.name
  region         = var.region # FR-017: region mas cercana a Azure; atributo a confirmar contra el provider real

  source_repo = var.source_repo != "" ? var.source_repo : null
}

module "tags" {
  source = "../../tags/common"

  tags = var.tags
}

module "network_domain" {
  source = "../../network-domain/railway"

  service_id     = railway_service.this.id
  environment_id = var.railway_environment_id
  domain_type    = var.domain_type
  custom_domain  = var.custom_domain
}

locals {
  # database_connection.secret_ref llega a este modulo ya resuelto (el valor sensible real,
  # leido por modules/database/azure-existing desde Key Vault) — nunca es un nombre de
  # secreto sin resolver en esta capa (FR-011).
  database_vars = var.database_connection != null ? {
    DATABASE_HOST     = var.database_connection.host
    DATABASE_PORT     = tostring(var.database_connection.port)
    DATABASE_PASSWORD = var.database_connection.secret_ref
  } : {}

  all_env_vars    = merge(var.env_vars, module.tags.introspection_vars)
  all_secret_vars = merge(var.secret_refs, local.database_vars)
}

resource "railway_variable" "env" {
  for_each = local.all_env_vars

  project_id     = var.railway_project_id
  environment_id = var.railway_environment_id
  service_id     = railway_service.this.id
  name           = each.key
  value          = each.value
}

resource "railway_variable" "secret" {
  for_each = local.all_secret_vars

  project_id     = var.railway_project_id
  environment_id = var.railway_environment_id
  service_id     = railway_service.this.id
  name           = each.key
  value          = each.value
  sensitive      = true
}
