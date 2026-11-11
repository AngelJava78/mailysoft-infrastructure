# Confirmado 2026-11-10 contra un `terraform plan` real + docs/resources/service.md del
# repositorio del provider (terraform-community-providers/terraform-provider-railway):
# "railway_service" solo exige "name" y "project_id", y NO tiene "environment_id" (el servicio
# se crea a nivel de proyecto, no de entorno). El atributo de region es "regions" (lista de
# objetos {region, num_replicas}), no "region" escalar. "source_repo" exige "source_repo_branch"
# cuando se usa (antes esta rama nunca se enviaba: var.source_ref se declaraba pero no se
# conectaba a ningun atributo del recurso, bug corregido en el mismo cambio). La alternativa
# del condicional de "regions" es "[]", no "null": con "null" el provider rechaza el plan con
# "Value Conversion Error" (confirmado contra un plan real).
resource "railway_service" "this" {
  project_id = var.railway_project_id
  name       = var.name

  source_repo        = var.source_repo != "" ? var.source_repo : null
  source_repo_branch = var.source_repo != "" ? var.source_ref : null

  # var.region (FR-017) NO se conecta a "regions" todavia: confirmado 2026-11-10 contra un
  # plan real que terraform-community-providers/railway 0.6.2 tiene un bug propio al
  # convertir ese atributo ("Value Conversion Error... Received unknown value, however the
  # target type cannot handle unknown values" - el mensaje de error dice explicitamente "This
  # is always an error in the provider"), reproducido tanto con una lista de un elemento como
  # con una lista vacia. Hasta que el provider lo corrija, el servicio se despliega en la
  # region por defecto de Railway.
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
  subdomain      = var.name
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

# Confirmado 2026-11-10 contra un plan real: "railway_variable" no tiene "project_id" (de
# solo lectura, se infiere de service_id) ni "sensitive" (el atributo "value" ya viene
# marcado Sensitive en el propio esquema del provider, redactado automaticamente en
# plan/state sin configuracion adicional - FR-011 queda cubierto igual).
resource "railway_variable" "env" {
  for_each = local.all_env_vars

  environment_id = var.railway_environment_id
  service_id     = railway_service.this.id
  name           = each.key
  value          = each.value
}

# "for_each" no admite un mapa con valores sensibles (DATABASE_PASSWORD deriva de
# random_password.postgres.result, sensible — modules/database/railway-managed/outputs.tf):
# iteramos solo sobre las keys (nombres de variable, nunca secretos en si) despojadas de la
# marca con nonsensitive(), y el value sensible se busca aparte por key.
resource "railway_variable" "secret" {
  for_each = nonsensitive(toset(keys(local.all_secret_vars)))

  environment_id = var.railway_environment_id
  service_id     = railway_service.this.id
  name           = each.key
  value          = local.all_secret_vars[each.key]
}
