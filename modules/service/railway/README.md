# modules/service/railway

Implementación operativa (Fase 1) del módulo de servicio sobre Railway. Ver el contrato
completo de entradas/salidas en
[contracts/service-module-interface.md](../../../specs/001-railway-deployment/contracts/service-module-interface.md).

## ⚠️ Advertencia de verificación pendiente

`terraform-community-providers/railway` es un provider **no oficial**. Durante la redacción
de este módulo no fue posible confirmar sus nombres exactos de recursos/atributos contra
`registry.terraform.io` (sin acceso a Terraform CLI ni al registro en ese momento — ver
[research.md](../../../specs/001-railway-deployment/research.md) sección 1 y el
[ADR 0001](../../../docs/adr/0001-railway-terraform-community-provider.md)). **Antes del
primer `terraform init` real**, confirmar contra la documentación/esquema real del provider:

- `railway_service` (atributos `project_id`, `environment_id`, `name`, `source_repo`)
- `railway_variable` (atributos `project_id`, `environment_id`, `service_id`, `name`, `value`, `sensitive`)
- `railway_service_domain` / `railway_custom_domain` (en `modules/network-domain/railway`)
- `railway_environment` (en `bootstrap/railway-project`)

Si algún nombre difiere, ajustar únicamente este módulo (y `network-domain/railway`): el
resto del repositorio no necesita cambios porque consume la interfaz común, no el provider
directamente.

## Ejemplo de uso

```hcl
module "usuarios_api" {
  source = "../../service/railway"

  name                   = "mailysoft-usuarios-api-dev"
  railway_project_id     = var.railway_project_id
  railway_environment_id = var.railway_environment_id
  source_repo            = "github.com/mailysoft/mailysoft-usuarios-api"
  domain_type            = "public"
  tags = {
    proyecto       = "mailysoft"
    servicio       = "usuarios-api"
    entorno        = "dev"
    propietario    = "equipo-plataforma"
    gestionado_por = "terraform"
  }
}
```
