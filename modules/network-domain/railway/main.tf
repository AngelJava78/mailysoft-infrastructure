# research.md seccion 4. La Private Networking de Railway esta activa por defecto para todo
# servicio dentro de un mismo Railway Environment (mesh WireGuard interno,
# <servicio>.railway.internal) y no requiere ningun recurso de Terraform adicional: por eso
# domain_type = "private" no crea nada en este modulo.
#
# ADVERTENCIA (research.md seccion 1): no se pudo confirmar contra el registro los nombres
# exactos de los recursos de dominio del provider comunitario. Se usa aqui el nombre mas
# plausible segun la terminologia propia de Railway ("Generate Domain" / "Custom Domain");
# verificar contra la documentacion real del provider antes del primer apply.

resource "railway_service_domain" "generated" {
  count = var.domain_type == "public" && var.custom_domain == "" ? 1 : 0

  service_id     = var.service_id
  environment_id = var.environment_id
}

resource "railway_custom_domain" "this" {
  count = var.domain_type == "public" && var.custom_domain != "" ? 1 : 0

  service_id     = var.service_id
  environment_id = var.environment_id
  domain         = var.custom_domain
}

locals {
  resolved_public_url = (
    length(railway_custom_domain.this) > 0 ? "https://${railway_custom_domain.this[0].domain}" :
    length(railway_service_domain.generated) > 0 ? "https://${railway_service_domain.generated[0].domain}" :
    null
  )
}
