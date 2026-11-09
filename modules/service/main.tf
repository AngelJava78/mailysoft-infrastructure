# Modulo fachada (interfaz comun del Principio III): despacha a la implementacion concreta
# del proveedor seleccionado en var.provider_name. "railway" y "azure" estan operativos desde
# 002-single-provider-deployment; "aws" sigue sin estar operativo y su submodulo sigue
# fallando la validacion de forma explicita (FR-005 de 001-railway-deployment) - ver
# modules/service/aws.
#
# Anadir un proveedor nuevo en una fase futura = anadir un submodulo mas aqui; ningun
# entorno ni servicio existente necesita cambiar (Principio III: agregar una API o, por
# extension, activar un proveedor nuevo, requiere solo configuracion).

module "railway" {
  count  = var.enabled && var.provider_name == "railway" ? 1 : 0
  source = "./railway"

  name                   = var.name
  railway_project_id     = var.railway_project_id
  railway_environment_id = var.railway_environment_id
  source_repo            = var.source_repo
  source_ref             = var.source_ref
  region                  = var.region
  domain_type             = var.domain_type
  custom_domain           = var.custom_domain
  env_vars                = var.env_vars
  secret_refs             = var.secret_refs
  resources               = var.resources
  database_connection     = var.database_connection
  tags                    = var.tags
}

module "azure" {
  count  = var.enabled && var.provider_name == "azure" ? 1 : 0
  source = "./azure"

  name                 = var.name
  enabled              = var.enabled
  source_repo          = var.source_repo
  source_ref           = var.source_ref
  container_image      = var.container_image
  domain_type          = var.domain_type
  custom_domain        = var.custom_domain
  env_vars             = var.env_vars
  secret_refs          = var.secret_refs
  resources            = var.resources
  database_connection  = var.database_connection
  tags                 = var.tags
  network              = var.azure_network
}

module "aws" {
  count  = var.enabled && var.provider_name == "aws" ? 1 : 0
  source = "./aws"

  name = var.name
}

locals {
  active_service_id = (
    length(module.railway) > 0 ? module.railway[0].service_id :
    length(module.azure) > 0 ? module.azure[0].service_id :
    null
  )
  active_public_url = (
    length(module.railway) > 0 ? module.railway[0].public_url :
    length(module.azure) > 0 ? module.azure[0].public_url :
    null
  )
  active_internal_address = (
    length(module.railway) > 0 ? module.railway[0].internal_address :
    length(module.azure) > 0 ? module.azure[0].internal_address :
    null
  )
}
