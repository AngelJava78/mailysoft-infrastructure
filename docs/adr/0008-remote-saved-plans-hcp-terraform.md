# ADR 0008: el plan aplicado es siempre el mismo artefacto que generó la etapa de revisión

**Estado**: Aceptado
**Fecha**: 2026-11-12
**Contexto**: [specs/003-reusable-pipeline-architecture](../../specs/003-reusable-pipeline-architecture/)

## Contexto

Al auditar los pipelines de despliegue para `003-reusable-pipeline-architecture` se confirmó, leyendo
el código real (no solo el diseño), una brecha entre lo que se revisa y lo que se aplica:

- `terraform-check-provider-mix` (usada hoy por `dev`/`staging`) ya ejecuta
  `terraform plan -out=check.tfplan` para decidir si el cambio necesita el gate de
  `manual-review` (FR-010/FR-014 de `002-single-provider-deployment`). Ese plan guardado se
  descartaba al terminar el job.
- `terraform-apply-env` ignoraba por completo ese plan y ejecutaba
  `terraform apply -auto-approve -var-file=...`, que **recalcula un plan nuevo** en el momento de
  aplicar — nunca el mismo que motivó el gate de revisión.
- `production` no llamaba a `terraform-check-provider-mix` en absoluto: aplicaba sin que existiera
  ningún plan previo mostrado a quien aprobaba el gate de GitHub Environment "production". Era el
  entorno con la garantía más débil, no la más fuerte.

`research.md` §1 de esa especificación identificó, contra la documentación oficial de HashiCorp
(`developer.hashicorp.com/terraform/cloud-docs/run/cli`, sección "Remote Saved Plans"), que HCP
Terraform (backend `cloud {}`, [ADR 0004](0004-backend-estado-desacoplado-de-proveedor.md)) ya
soporta nativamente lo que se necesitaba: generar un plan en una máquina (un job de CI) y aplicarlo
desde otra, con detección automática de obsolescencia si el estado real cambia entre ambos pasos.

## Decisión

El job `apply` de cada entorno aplica siempre el artefacto de plan que generó el job `check` de la
**misma invocación** del pipeline — nunca recalcula uno nuevo:

- `terraform-check-provider-mix` guarda su plan como `${environment}.tfplan` (antes
  `check.tfplan`, sin calificar) y lo publica como artefacto del run de GitHub Actions
  (`actions/upload-artifact@v4`, nombre `tfplan-<environment>`).
- `terraform-apply-env` descarga ese artefacto (`actions/download-artifact@v4`) y ejecuta
  `terraform apply <environment>.tfplan` — nunca `-auto-approve -var-file=...` combinado con un
  plan guardado (Terraform rechaza esa combinación).
- Si HCP Terraform detecta que el plan quedó obsoleto (el estado real del entorno cambió después de
  generarse — algo que HCP Terraform detecta y descarta automáticamente, sin lógica propia que
  construir), el `apply` falla de forma visible en vez de aplicar algo distinto en su lugar.
- `production` deja de ser un caso especial: pasa a ejecutar el mismo `check` que `dev`/`staging`
  antes de aplicar (ver [ADR 0009](0009-workflow-reutilizable-por-entorno.md)), así que por primera
  vez existe un plan real que revisar antes de aprobar su despliegue.

## Alternativas consideradas

- **Mantener `apply -auto-approve -var-file=...` (comportamiento anterior)**: rechazada — es
  exactamente la brecha que esta decisión existe para cerrar; ninguna aprobación quedaba realmente
  atada al cambio que se aplicaba.
- **Replicar el mecanismo de un backend clásico (archivo de plan completo como artefacto de build,
  sin depender de HCP Terraform)**: rechazada — exigiría abandonar el bloque `cloud` y revertir
  [ADR 0004](0004-backend-estado-desacoplado-de-proveedor.md), una regresión mucho mayor que el
  problema que se intenta resolver.
- **Conectar el workspace de HCP Terraform directamente al repositorio (runs disparados por HCP
  Terraform, sin pasos de Terraform en GitHub Actions)**: rechazada para esta fase — eliminaría los
  gates de aprobación nativos de GitHub Environment ya vigentes, y es un cambio de arquitectura
  mucho mayor que el alcance de esta decisión.

## Consecuencias

- `terraform-check-provider-mix/action.yml` y `terraform-apply-env/action.yml` cambian de
  comportamiento (no de contrato de entrada/salida): la primera ahora publica un artefacto; la
  segunda ahora lo consume en vez de recibir `-var-file` en el momento de aplicar.
- El mecanismo depende de que los workspaces de HCP Terraform (`mailysoft-dev/staging/production`)
  tengan *Execution Mode* = "Local" — ya documentado como parte de la decisión original de
  [ADR 0004](0004-backend-estado-desacoplado-de-proveedor.md) (2026-11-09), reconfirmado
  visualmente antes de depender de esto en `production`
  (specs/003-reusable-pipeline-architecture/quickstart.md §1).
- Por primera vez, `production` genera y expone un plan antes de que alguien apruebe su
  despliegue — una mejora de seguridad real, no solo una reorganización de código.
