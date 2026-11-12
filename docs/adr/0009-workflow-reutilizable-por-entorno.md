# ADR 0009: un workflow reutilizable por entorno, no tres jobs triplicados y encadenados

**Estado**: Aceptado
**Fecha**: 2026-11-12
**Contexto**: [specs/003-reusable-pipeline-architecture](../../specs/003-reusable-pipeline-architecture/)

## Contexto

El patrón de referencia analizado en `003-reusable-pipeline-architecture` (un proyecto externo de
Terraform + Azure DevOps que el operador ya usa en otros contextos) declara la lógica de pipeline
una sola vez, en una plantilla reutilizable, y representa cada entorno únicamente con un archivo
delgado de configuración que la invoca.

El `terraform-apply.yml` de este repositorio no seguía ese patrón: triplicaba el mismo job graph
(`check` → `manual-review` → `apply`) una vez por entorno dentro del mismo archivo, y además los
encadenaba con `needs` (`apply-dev` → `apply-staging` → `apply-production`). Esto violaba dos cosas
a la vez:

- **FR-006/FR-007** (`003-reusable-pipeline-architecture`): la lógica de pipeline debía escribirse
  una sola vez; aquí estaba escrita tres veces (aunque reutilizando las mismas composite actions,
  el *job graph* que las orquestaba sí estaba triplicado).
- **FR-008**: ningún entorno debía esperar ni depender de otro. Con `needs` explícito,
  `staging` no podía aplicarse sin que `dev` ya hubiera corrido en la misma invocación, y
  `production` sin que `staging` lo hiciera — exactamente lo contrario de "un entorno a la vez"
  que motivó, en esta misma sesión, el rediseño de los proyectos de Railway (ADR 0006).

## Decisión

Un workflow reutilizable de GitHub Actions, `.github/workflows/terraform-environment.yml`
(`on: workflow_call`), concentra el job graph completo — `check` (plan de solo lectura,
FR-010/FR-014) → `manual-review` (condicional a `requires_review`) → `apply` (con el plan de
`check`, [ADR 0008](0008-remote-saved-plans-hcp-terraform.md)) — parametrizado por un único input,
`environment`.

Tres archivos delgados (`terraform-apply-dev.yml`, `terraform-apply-staging.yml`,
`terraform-apply-production.yml`) sustituyen a `terraform-apply.yml`: cada uno declara su propio
disparador (`push` a `main`, filtrado por las rutas propias de ese entorno más los archivos
compartidos del root) y los secretos de ese entorno, sin ningún `needs` entre ellos.

El job `apply`, dentro del workflow reutilizable, declara `environment: ${{ inputs.environment }}`.
Esto es lo que permite que `production` siga exigiendo su aprobación nativa de GitHub Environment
(ya configurada, sin cambios) sin ninguna condición nueva en el código: GitHub evalúa las reglas de
protección del nombre de entorno *resuelto* en tiempo de ejecución, no del texto literal del YAML.
`dev`/`staging` no tienen reglas configuradas, así que ese job pasa de inmediato — mismo
comportamiento que antes.

## Alternativas consideradas

- **Un único `terraform-apply.yml` con los tres entornos como jobs en paralelo (sin `needs`), en
  vez de tres archivos separados**: resuelve FR-008 a nivel de ejecución, pero no evita el disparo
  innecesario — cualquier push que tocara `environments/**` seguiría replaneando (y, si aplica,
  pidiendo aprobación) para los tres entornos aunque solo uno hubiera cambiado. Rechazada por ese
  efecto colateral de ruido en el gate de `manual-review`.
- **Un workflow reutilizable por etapa** (uno para `check`, otro para `apply`) en vez de uno por
  entorno con las tres etapas dentro: rechazada por fragmentar sin necesidad una secuencia que ya
  es cohesiva, sin aportar nada que el diseño elegido no logre ya.
- **Mover también la condición de `manual-review` a un Environment dinámico por entorno**:
  rechazada — `manual-review` es una propiedad del cambio (destructivo o con mezcla de
  proveedores), no del entorno; un único Environment `manual-review` compartido sigue siendo la
  representación correcta.

## Consecuencias

- `.github/workflows/terraform-apply.yml` se elimina por completo.
- Añadir un entorno nuevo (README, "Añadir un entorno nuevo") deja de requerir tocar
  `terraform-environment.yml`: solo un archivo delgado nuevo con sus propios disparador y
  secretos.
- `production` pasa a ejecutar el mismo `check` que `dev`/`staging` antes de aplicar — ver
  [ADR 0008](0008-remote-saved-plans-hcp-terraform.md) para esa consecuencia específica.
- `terraform-pr.yml` y `terraform-drift.yml` no cambian: ya ejecutaban los tres entornos en
  paralelo mediante una matriz, sin `needs` entre ellos, para su propio propósito de solo lectura.
