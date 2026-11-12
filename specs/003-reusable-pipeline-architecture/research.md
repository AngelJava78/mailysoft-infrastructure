# Research: Arquitectura de Referencia — Una Sola Declaración de Recursos y Pipelines Reutilizables por Entorno

**Fecha**: 2026-11-11 | **Spec**: [spec.md](./spec.md) | **Constitución**: [constitution.md](../../.specify/memory/constitution.md)

Este documento resuelve las decisiones técnicas de esta fase. El patrón de "una sola declaración de
recursos, variable por entorno mediante configuración" para el root de Terraform de Railway
(`environments/`) ya está resuelto por [ADR 0007](../../docs/adr/0007-root-unico-environments.md) y
no se reabre aquí (FR-001/FR-002 ya están satisfechos para Railway; esta fase solo los fija como
regla permanente para cuando exista el root de Azure — FR-004). El contenido nuevo de esta fase es
sobre pipelines de CI/CD (FR-006 a FR-012).

## 1. Vincular el plan revisado con el plan aplicado (FR-009/FR-010)

**Hallazgo de partida** (inspeccionando el código real, no solo el spec): `terraform-check-provider-mix`
(`.github/actions/terraform-check-provider-mix/action.yml`) ya ejecuta `terraform plan -out=check.tfplan`
y solo usa `terraform show -json` sobre ese archivo para decidir si el entorno necesita el gate de
`manual-review` (FR-010/FR-014 de 002). Ese plan guardado se descarta al terminar el job. Por su
parte, `terraform-apply-env` (`.github/actions/terraform-apply-env/action.yml`) ignora por completo
ese plan y ejecuta `terraform apply -auto-approve -var-file=...`, que **recalcula un plan nuevo** en
el momento de aplicar. Para `production`, la brecha es mayor: su job de `terraform-apply.yml` ni
siquiera llama a `terraform-check-provider-mix` — hoy aplica sin que exista ningún plan previo
mostrado a quien aprueba el gate de GitHub Environment "production".

**Decision**: Adoptar el flujo de "Remote Saved Plans" de HCP Terraform (ADR 0004: este repo ya usa
el bloque `cloud {}`, no un backend clásico): el job `check` de cada entorno genera el plan con
`-out=<entorno>.tfplan` (ya lo hace) y lo publica como artefacto del mismo run de GitHub Actions; el
job `apply` descarga ese artefacto y ejecuta `terraform apply <entorno>.tfplan` en vez de
`-auto-approve -var-file=...`. Se aplica a los tres entornos por igual, incluyendo `production`
(hoy es el único que no tiene ningún plan previo antes de aplicar).

**Rationale**: Confirmado contra la documentación oficial de HashiCorp
(`developer.hashicorp.com/terraform/cloud-docs/run/cli`, sección "Remote Saved Plans", Terraform
CLI ≥ 1.6.0 — este repo fija 1.17.x):
- El patrón está nombrado explícitamente como un caso de uso de CI: *"Perform the plan and apply
  operations on separate machines (as is common in continuous integration workflows)"*.
- El archivo guardado por `-out` **no** es un plan portátil completo — es *"a thin reference to a
  remote run"*. Lo que viaja entre jobs de GitHub Actions es solo esa referencia; el contenido real
  del plan sigue en HCP Terraform. Por eso el mismo mecanismo que ya usa este repo
  (`TF_CLOUD_ORGANIZATION`/`TF_WORKSPACE`/`TF_TOKEN_app_terraform_io`) basta para que el job de
  `apply` (una máquina distinta a la del job `check`) pueda aplicar esa referencia.
- La detección de "plan obsoleto" (FR-010) es automática y nativa, no hay que construirla: *"saved
  plans become stale once the state Terraform planned them against is no longer valid... stale saved
  plan runs are automatically detected and discarded"*. Si algo más aplica un cambio al mismo entorno
  entre el `check` y el `apply`, HCP Terraform rechaza ese plan por sí mismo.
- Como efecto secundario, igualar el job graph de `production` al de `dev`/`staging` (con su propio
  `check` antes de aplicar) corrige la brecha de seguridad real que tiene hoy production: quien
  aprueba el gate de GitHub Environment puede abrir los logs del job `check` de ese run concreto y
  ver exactamente el plan que está a punto de aplicarse, en vez de aprobar a ciegas.

**Riesgo inicialmente marcado como "a confirmar", resuelto contra la propia historia del
repositorio**: la documentación de HashiCorp advierte, en el contexto de workspaces configurados
con *Execution Mode* "Remote" (donde HCP Terraform ejecuta el propio `terraform apply` en sus
workers), que *"HCP Terraform does not support uploading saved plans for remote execution"* — lo
que en apariencia podría chocar con el traspaso de artefacto entre jobs que propone esta decisión.
Pero [ADR 0004](../../docs/adr/0004-backend-estado-desacoplado-de-proveedor.md) ya documenta, como
parte de la decisión original de adoptar HCP Terraform (2026-11-09), que los tres workspaces se
crearon deliberadamente con **Execution Mode = "Local"**, *"para no romper el parseo de
`plan.json` que ya usan FR-010/FR-014"* — exactamente el modo para el que la documentación confirma
el patrón de traspaso entre máquinas sin la advertencia anterior. No es una suposición nueva de
esta fase: es la configuración que ya existe desde que se adoptó HCP Terraform. **Antes de
depender de esto en `production`**, de todas formas corresponde una confirmación visual rápida
(Workspace → Settings → General → Execution Mode en los tres workspaces, quickstart.md §1) — por
si algo cambió esa configuración desde 2026-11-09 — y probarlo de extremo a extremo en `dev`
primero antes de extenderlo a `staging`/`production`.

**Alternatives considered**:
- *Mantener `apply -auto-approve -var-file=...` (comportamiento actual)*: rechazado — es exactamente
  la brecha que FR-009 exige cerrar; ninguna aprobación (manual-review o production) está realmente
  atada al cambio que se aplica.
- *Replicar literalmente el mecanismo de `tf-terranova` (backend clásico + archivo de plan completo
  como artefacto de build)*: rechazado — exigiría abandonar el bloque `cloud` y revertir
  [ADR 0004](../../docs/adr/0004-backend-estado-desacoplado-de-proveedor.md) (backend de estado
  desacoplado del proveedor), una regresión mucho mayor que el alcance de esta fase.
- *Conectar el workspace de HCP Terraform directamente al repositorio de GitHub (runs disparados por
  HCP Terraform mismo, sin pasos de Terraform en GitHub Actions)*: rechazado para esta fase — eliminaría
  los gates de aprobación nativos de GitHub Environment (FR-011, ya vigentes) y es un cambio de
  arquitectura mucho más grande que el alcance de esta especificación.

## 2. Lógica de pipeline reutilizable y entornos independientes (FR-006/FR-007/FR-008/FR-011/FR-012)

**Decision**: Un solo workflow reutilizable de GitHub Actions
(`.github/workflows/terraform-environment.yml`, `on: workflow_call`, parametrizado por el input
`environment`) contiene el job graph completo ya existente — `check` (plan + FR-010/FR-014) →
`manual-review` (condicional a `requires_review`) → `apply` (con el plan guardado, §1) — reutilizando
sin cambios las dos composite actions ya existentes. El job `apply` declara
`environment: ${{ inputs.environment }}`: para `dev`/`staging` no hay reglas de protección
configuradas en GitHub (pasa de inmediato, igual que hoy), y para `production` GitHub aplica
automáticamente las reglas ya configuradas (reviewer requerido) sin ninguna condición especial en el
YAML. Tres archivos delgados (`terraform-apply-dev.yml`, `terraform-apply-staging.yml`,
`terraform-apply-production.yml`) sustituyen al `terraform-apply.yml` actual: cada uno solo declara su
propio disparador (`push` a `main`, filtrado por las rutas propias de ESE entorno más los archivos
compartidos del root) y los parámetros/secretos de ese entorno al invocar el workflow reutilizable.
Ninguno depende (`needs`) de los otros.

**Rationale**:
- Satisface FR-006/FR-007 reutilizando, no reescribiendo, lo que ya existe: las dos composite actions
  (`terraform-apply-env`, `terraform-check-provider-mix`) ya son "lógica escrita una sola vez"; lo que
  falta es que el *job graph* que las orquesta también lo esté, en vez de estar triplicado dentro de
  `terraform-apply.yml` como ocurre hoy.
- Satisface FR-008: sin `needs` entre entornos, el pipeline de uno puede dispararse, reintentarse
  (GitHub ya soporta "re-run failed jobs" por job) o fallar sin bloquear ni esperar a los demás.
- Filtrar las rutas de cada disparador por entorno (en vez de un único `push: paths: [environments/**]`
  compartido, como hoy) evita el efecto colateral de volver a planear y, peor, volver a disparar el
  gate de `manual-review` de `staging`/`production` cuando solo cambió la configuración de `dev` — algo
  que sí ocurriría con un único workflow de tres jobs en paralelo disparado por el mismo evento.
- `environment: ${{ inputs.environment }}` dentro de un workflow reutilizable está soportado por
  GitHub Actions (las reglas de protección de un "Environment" se evalúan igual dentro de un job de un
  `workflow_call` que en un job normal); esto es lo que permite que production siga exigiendo su
  aprobación nativa (FR-011) sin condicionales nuevos en el código del pipeline.
- Unificar el job graph de los tres entornos (hoy `production` se saltaba `check`/`manual-review` por
  completo) es una simplificación, no una complejidad nueva: los tres entornos quedan con la misma
  lógica, y production gana la verificación previa que hoy le falta (ver §1).

**Alternatives considered**:
- *Mantener un único `terraform-apply.yml` pero con los tres jobs en paralelo (sin `needs` entre
  ellos), en vez de tres archivos separados*: resuelve FR-008 a nivel de ejecución (los jobs no se
  esperan entre sí), pero no resuelve el disparo innecesario: cualquier push a `main` que toque
  `environments/**` seguiría replaneando y, si corresponde, pidiendo aprobación para los tres entornos
  aunque solo uno haya cambiado. Rechazada por ese efecto colateral, no por incumplir FR-008 en sí.
- *Workflow reutilizable por etapa (uno para `check`, otro para `manual-review`, otro para `apply`) en
  vez de uno por entorno con las tres etapas dentro*: rechazada por fragmentar sin necesidad algo que
  ya es una sola secuencia cohesiva; no aporta nada que el diseño elegido no logre ya.
- *Mover la aprobación de `manual-review` también a un `environment: ${{ inputs.environment }}-review`
  dinámico por entorno*: rechazada — `manual-review` es una propiedad del **cambio** (si es
  destructivo o mezcla proveedores, FR-010/FR-014), no del entorno; un solo Environment
  `manual-review` compartido, igual que hoy, es la representación correcta.

## 3. Alcance del lado de integración continua (`terraform-pr.yml`) y de detección de drift

**Decision**: `terraform-pr.yml` (plan en pull requests) y `terraform-drift.yml` (detección
periódica) no requieren cambios estructurales en esta fase.

**Rationale**: Ambos ya ejecutan los tres entornos en paralelo mediante una matriz dentro de un único
workflow, sin encadenarlos con `needs` — ya satisfacen FR-006/FR-008 para su propio propósito (una
vista previa de solo lectura, nunca una aplicación). La garantía que exige FR-009/FR-010 — "el plan
revisado es el aplicado" — se ata al gate de *aprobación de despliegue* (`manual-review`/`production`,
dentro de `terraform-environment.yml`, §1), no a la vista previa de la pull request: son dos momentos
de revisión distintos (revisar código antes de fusionar vs. aprobar un despliegue), y esta
especificación solo exige que el segundo esté correctamente atado, que es lo que corrige §1 y §2.

**Alternatives considered**:
- *Unificar también `terraform-pr.yml` bajo el mismo workflow reutilizable que `terraform-environment.yml`*:
  evaluada y descartada para esta fase — su job graph (solo plan + Checkov, sin aprobación ni apply) es
  distinto al de despliegue, y forzar una sola plantilla para ambos agregaría parámetros condicionales
  sin necesidad real. Queda como una simplificación posible de una fase futura, no un requisito de esta.

## 4. Compatibilidad hacia delante con el futuro root de Azure (FR-004)

**Decision**: No se crea ningún archivo de Terraform de Azure en esta fase (Out of Scope del spec).
Se añade al README la regla explícita de que el primer archivo de recursos de Azure MUST nacer
siguiendo el mismo patrón que `environments/` (una sola declaración, variables/`.tfvars` por entorno,
sin copiar archivos), citando esta especificación — como documentación, no como código.

**Rationale**: Es la única acción posible hoy sin construir el root de Azure en sí, que es trabajo de
una fase posterior (Principio II, Fase 2); fijar la regla por escrito ahora es lo que FR-004 exige:
que esa fase futura no tenga que redescubrir, a base de los mismos errores ya corregidos en Railway
([ADR 0007](../../docs/adr/0007-root-unico-environments.md)), que la variación por entorno es
configuración, no código.

**Alternatives considered**:
- *Dejarlo sin documentar y confiar en que quien construya Azure revise las especificaciones
  anteriores*: rechazada — es precisamente el tipo de conocimiento tácito que ya causó la duplicación
  original en Railway; esta especificación existe para no repetir ese costo.
