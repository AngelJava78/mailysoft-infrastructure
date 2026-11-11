# ADR 0001: usar el provider comunitario de Terraform para Railway

**Estado**: Aceptado
**Fecha**: 2026-10-24
**Contexto**: [specs/001-railway-deployment](../../specs/001-railway-deployment/)

## Contexto

La constitución del repositorio (Principio III) exige que toda la infraestructura se defina
con Terraform, y prohíbe crear o modificar recursos manualmente en las consolas de los
proveedores. La Fase 1 de la estrategia multi-nube usa Railway como proveedor operativo.

Durante la investigación (ver
[research.md](../../specs/001-railway-deployment/research.md) sección 1) se encontró que:

- No existe un provider de Terraform oficial mantenido por Railway.
- El único provider disponible en el registro de Terraform es
  `terraform-community-providers/railway`, mantenido por la comunidad.
- El personal de Railway ha declarado públicamente que no recomienda usar IaC sobre su
  plataforma, y sugiere el dashboard o su propio formato `railway.toml`.
- Se han reportado errores 503 de la API de Railway al gestionar más de ~50-70 recursos en
  una sola operación con ese provider.

## Decisión

Usar `terraform-community-providers/railway`, fijando su versión exacta, como la
implementación de `modules/service/railway` y `modules/network-domain/railway`. Es la única
opción que permite cumplir el Principio III sin tocar la consola de Railway manualmente.

## Alternativas consideradas

- **`railway.toml` o el dashboard de Railway**: rechazado porque viola directamente el
  Principio III y el Principio I (nunca crear/modificar recursos manualmente).
- **Esperar a un provider oficial**: rechazado porque bloquearía indefinidamente la Fase 1
  sin fecha conocida de disponibilidad.

## Consecuencias

- **Riesgo operativo aceptado**: posibles errores 503 al escalar a muchos recursos, y
  comportamiento no garantizado por Railway. Mitigación: aplicar en lotes pequeños, fijar
  versión del provider, monitorear sus issues en GitHub, y mantener un procedimiento de
  recuperación manual documentado (`docs/runbooks/bootstrap.md`,
  `docs/runbooks/rollback.md`).
- **Riesgo de esquema no verificado**: durante la implementación de
  `modules/service/railway`, `modules/network-domain/railway` y
  `bootstrap/railway-project`, no fue posible confirmar los nombres exactos de
  recursos/atributos del provider contra su documentación real (sin acceso a Terraform CLI
  ni al registro en ese momento). Cada uno de esos módulos señala explícitamente, en su
  propio código y README, qué verificar antes del primer `terraform init` real.
  **Actualización 2026-11-09**: `bootstrap/railway-project` (`railway_project`,
  `railway_environment`) quedó confirmado contra la documentación real del provider — ver
  `docs/runbooks/bootstrap.md`. `modules/service/railway`, `modules/network-domain/railway` y
  el riesgo adicional de `modules/database/railway-managed` (ADR 0003) siguen sin verificar.
- **Revisar esta decisión** si Railway publica un provider oficial, o si el provider
  comunitario deja de mantenerse.
