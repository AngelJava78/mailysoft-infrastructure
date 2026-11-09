# modules/database/railway-managed

Implementación Railway de la interfaz común de "base de datos del entorno" — contrato
completo en
[contracts/database-module-interface.md](../../../specs/002-single-provider-deployment/contracts/database-module-interface.md).
Se usa cuando `environment_provider = "railway"` y el entorno todavía no tiene una base de
datos propia ahí (FR-011). A diferencia de `modules/database/azure-existing`, este módulo
**crea y administra** su propio recurso: nunca lee, referencia ni depende de
`mailysoft-db` en Azure (FR-012).

## ⚠️ Advertencia de verificación pendiente

Igual que `modules/service/railway/README.md` de la Fase 1, este módulo usa
`terraform-community-providers/railway`, un provider **no oficial**. No se pudo confirmar,
durante su redacción, que el provider exponga:

1. Un recurso de volumen persistente (`railway_volume`) con el nombre y los atributos
   exactos usados aquí — la comunidad de Railway ha reportado al menos un error 504 al
   crear un volumen con este provider.
2. Un atributo `source_image` en `railway_service` para desplegar desde una imagen de
   contenedor en vez de un repositorio (`source_repo`, el único atributo usado hasta ahora
   en `modules/service/railway`).

**Antes del primer `terraform init`/`apply` real de este módulo**, confirmar ambos contra
`registry.terraform.io/providers/terraform-community-providers/railway/latest`. Si el
recurso de volumen no existe, la alternativa documentada en
[research.md §3](../../../specs/002-single-provider-deployment/research.md) es usar la
plantilla de un clic de Railway para Postgres fuera de Terraform para este caso puntual,
documentado como excepción — nunca creando el recurso manualmente sin dejar rastro (Principio
I/III).

## Qué crea

Un `railway_service` desde `ghcr.io/railwayapp-templates/postgres-ssl` (imagen oficial de
Postgres con SSL que publica Railway, confirmada contra su documentación), un `railway_volume`
montado en `/var/lib/postgresql/data`, y las variables `POSTGRES_DB`/`POSTGRES_USER` (no
sensibles) y `POSTGRES_PASSWORD` (generada con `random_password`, sensible).

## Entradas / Salidas

Ver variables.tf/outputs.tf y el contrato común enlazado arriba. `kind` es siempre
`"administrada"`.

## Ejemplo de uso

```hcl
module "mailysoft_db_railway" {
  source = "../../modules/database/railway-managed"
  count  = var.environment_provider == "railway" && anytrue([for s in var.services : s.requires_database]) ? 1 : 0

  environment_name       = var.environment_name
  railway_project_id     = var.railway_project_id
  railway_environment_id = var.railway_environment_id
  database_name          = "mailysoft_${var.environment_name}"
  region                 = var.region_hint
}
```
