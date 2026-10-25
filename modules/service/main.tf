# Modulo fachada (interfaz comun del Principio III): despacha a la implementacion concreta
# del proveedor seleccionado en var.provider_name. Los proveedores "azure" y "aws" no estan
# operativos en esta fase y su submodulo siempre falla la validacion de forma explicita
# (FR-005) - ver modules/service/azure y modules/service/aws.
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

  name = var.name
}

module "aws" {
  count  = var.enabled && var.provider_name == "aws" ? 1 : 0
  source = "./aws"

  name = var.name
}

locals {
  active_service_id       = var.provider_name == "railway" && length(module.railway) > 0 ? module.railway[0].service_id : null
  active_public_url       = var.provider_name == "railway" && length(module.railway) > 0 ? module.railway[0].public_url : null
  active_internal_address = var.provider_name == "railway" && length(module.railway) > 0 ? module.railway[0].internal_address : null
}
