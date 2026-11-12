---

description: "Task list template for feature implementation"
---

# Tasks: Arquitectura de Referencia — Una Sola Declaración de Recursos y Pipelines Reutilizables por Entorno

**Input**: Design documents from `/specs/003-reusable-pipeline-architecture/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md (todos ya generados)

**Tests**: Esta fase no introduce pruebas automatizadas nuevas; las validaciones son los escenarios de `quickstart.md`, incluidos como tareas de verificación dentro de cada historia.

**Organización**: FR-001/FR-002 (una sola declaración de recursos por proveedor, variable por entorno) ya están satisfechos para Railway desde ADR 0007 y no se tocan en esta fase — las tareas de abajo cubren únicamente lo que spec.md marca como brecha real: los pipelines de CI/CD (US1/US2), su demostración al añadir un entorno (US3), y la regla documentada para el futuro proveedor Azure (US4).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Puede ejecutarse en paralelo (archivos distintos, sin dependencias pendientes)
- **[Story]**: A qué historia de usuario pertenece (US1-US4)
- Cada tarea incluye la ruta exacta de archivo

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: fijar las versiones de acciones nuevas que esta fase introduce por primera vez en el repositorio, y confirmar que el punto de partida sigue siendo el descrito en research.md antes de modificar nada.

- [X] T001 [P] Fijar `actions/upload-artifact@v4` y `actions/download-artifact@v4` como las versiones a usar en toda esta fase (ninguna de las dos se usa hoy en este repositorio); documentarlo en un comentario junto a su primer uso real (T013), consistente con el resto de acciones ya fijadas por versión exacta (`actions/checkout@v4`, `hashicorp/setup-terraform@v3`) — Principio III: nunca un rango abierto
- [X] T002 [P] Releer `.github/workflows/terraform-apply.yml`, `.github/actions/terraform-check-provider-mix/action.yml` y `.github/actions/terraform-apply-env/action.yml`, y confirmar que coinciden con el "Hallazgo de partida" de [research.md §1](./research.md): `production` no llama a `terraform-check-provider-mix` (no genera plan previo) y `terraform-apply-env` aplica con `-auto-approve -var-file=...` (recalcula, no reutiliza el plan de `check`). Si algún archivo ya cambió desde que se escribió este plan, detener y re-ejecutar `/speckit-plan` antes de continuar con las fases siguientes

**Checkpoint**: la base sobre la que se escribió este plan queda confirmada vigente.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: precondición operativa de la que depende US2 (y, por extensión, la parte de US3 que reutiliza el mecanismo de plan guardado). **US1 no depende de esta fase y puede implementarse en paralelo.**

**⚠️ CRITICAL**: no continuar con US2 hasta completar esta fase.

- [ ] T003 En HCP Terraform (organización `angel-java`), confirmar en cada workspace —
      `mailysoft-dev`, `mailysoft-staging`, `mailysoft-production` — que **Settings → General →
      Execution Mode = "Local"** ([quickstart.md §1](./quickstart.md)). Si alguno no lo es,
      cambiarlo a "Local" antes de continuar, o registrar el hallazgo como bloqueador de US2 y
      detenerse ahí ([research.md §1](./research.md), riesgo documentado sin confirmar para el modo
      "Remote"/"Agent")

**Checkpoint**: el mecanismo de "Remote Saved Plans" (research.md §1) queda validado como aplicable antes de construir nada sobre él.

---

## Phase 3: User Story 1 - Ejecutar o revertir un entorno sin arrastrar a los demás (Priority: P1) 🎯 MVP

**Goal**: cada entorno (dev, staging, production) se dispara, reintenta o falla sin iniciar, esperar ni depender de la ejecución de los demás.

**Independent Test**: un cambio exclusivo de la configuración de `dev` dispara únicamente su propio pipeline; staging/production no se ejecutan ni quedan pendientes (spec.md, US1).

### Implementation for User Story 1

- [X] T004 [US1] Crear `.github/workflows/terraform-environment.yml` con `on: workflow_call`;
      declarar el input `environment` (string, requerido) y los secrets `azure-client-id`,
      `azure-tenant-id`, `azure-subscription-id`, `railway-token`, `tfc-token` (todos requeridos) más
      el input `tf-version` — contrato exacto en
      [contracts/reusable-pipeline-interface.md](./contracts/reusable-pipeline-interface.md),
      sección "Entrada"
- [X] T005 [US1] En `terraform-environment.yml` (depende de T004), definir el job `check`: misma
      lógica que usa hoy `terraform-check-provider-mix` (se invoca aquí sin cambios de
      comportamiento en esta historia — ver US2 para el cambio real de esa composite action),
      expone el output `requires_review`
- [X] T006 [US1] En `terraform-environment.yml` (depende de T005), definir el job `manual-review`:
      `needs: check`; `if: needs.check.outputs.requires_review == 'true'`; `environment:
      manual-review` (mismo comportamiento que el `manual-review-dev`/`manual-review-staging` de
      hoy, sin cambios)
- [X] T007 [US1] En `terraform-environment.yml` (depende de T005, T006), definir el job `apply`:
      `needs: [check, manual-review]`; `if: always() && needs.check.result == 'success' &&
      (needs.manual-review.result == 'success' || needs.manual-review.result == 'skipped')`;
      `environment: ${{ inputs.environment }}` — así `production` hereda su gate de aprobación
      nativo ya configurado sin ninguna condición nueva en el YAML (FR-011,
      contracts/reusable-pipeline-interface.md "Comportamiento garantizado")
- [X] T008 [P] [US1] Crear `.github/workflows/terraform-apply-dev.yml`: `on: push: branches:
      [main], paths: ["environments/dev/**", "environments/*.tf", "modules/**"]`; un job que invoca
      `terraform-environment.yml` (T004-T007) con `environment: dev` y los secretos
      `RAILWAY_TOKEN_DEV`, `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`,
      `TFC_API_TOKEN`
- [X] T009 [P] [US1] Crear `.github/workflows/terraform-apply-staging.yml`: mismo patrón que T008
      con `paths: ["environments/staging/**", "environments/*.tf", "modules/**"]`, `environment:
      staging`, secreto `RAILWAY_TOKEN_STAGING`
- [X] T010 [P] [US1] Crear `.github/workflows/terraform-apply-production.yml`: mismo patrón con
      `paths: ["environments/production/**", "environments/*.tf", "modules/**"]`, `environment:
      production`, secreto `RAILWAY_TOKEN_PRODUCTION`
- [X] T011 [US1] Eliminar `.github/workflows/terraform-apply.yml` (depende de que T008-T010 ya
      estén creados — contracts/reusable-pipeline-interface.md, sección "Quién lo invoca"; el job
      graph que triplicaba y encadenaba dev→staging→production queda sustituido por completo)
- [ ] T012 [US1] Ejecutar [quickstart.md §4](./quickstart.md) contra un cambio real: (a) un cambio
      exclusivo de `environments/dev/**` → confirmar que solo `terraform-apply-dev.yml` se dispara;
      (b) un cambio exclusivo de `environments/staging/**` → confirmar lo simétrico; (c) un cambio
      en `environments/main.tf` → confirmar que esta vez se disparan los tres (contraprueba: es
      compartido de verdad, FR-002)

**Checkpoint**: US1 funcional — los tres entornos son pipelines independientes, sin `needs` entre
ellos. (Todavía sin el fix de "plan revisado = plan aplicado"; eso es US2, independiente de esta
historia.)

---

## Phase 4: User Story 2 - El plan revisado es el plan aplicado (Priority: P1)

**Goal**: `apply` nunca recalcula un plan — aplica el que generó `check` en la misma invocación; un
plan obsoleto se rechaza en vez de sustituirse en silencio.

**Independent Test**: modificar deliberadamente el estado real de un entorno después de generar un
plan ya revisado, y confirmar que el pipeline detiene la aplicación en vez de aplicar un plan
recalculado (spec.md, US2). **Depende de la Fase 2 (T003); no depende de US1** — modifica solo las
composite actions, que hoy también usa `terraform-apply.yml` sin cambios.

### Implementation for User Story 2

- [X] T013 [US2] En `.github/actions/terraform-check-provider-mix/action.yml` (depende de T001,
      T003): renombrar el archivo de plan generado por el step "terraform plan (solo lectura)" de
      `check.tfplan` a `${{ inputs.environment }}.tfplan` (sin tocar el resto del comando), y
      añadir un step `actions/upload-artifact@v4` que lo publique con `name:
      tfplan-${{ inputs.environment }}` — contracts/plan-artifact-handoff.md, "Productor: job check"
- [X] T014 [US2] En `.github/actions/terraform-apply-env/action.yml` (depende de T013): añadir, al
      inicio de los steps, un `actions/download-artifact@v4` que descargue `tfplan-${{
      inputs.environment }}` — contracts/plan-artifact-handoff.md, "Consumidor: job apply"
- [X] T015 [US2] En el mismo archivo (depende de T014): reemplazar el step "terraform apply" —
      cambiar `terraform apply -input=false -auto-approve -no-color -var-file="..." -var-file="..."
      -var-file="..."` por `terraform apply -input=false -no-color
      ${{ inputs.environment }}.tfplan` (un plan guardado no admite `-var-file` ni `-auto-approve`
      combinados con él; contracts/plan-artifact-handoff.md)
- [ ] T016 [US2] Confirmar (probándolo una vez en `dev`, documentando el resultado en un comentario
      del propio `action.yml`) que si el artefacto `tfplan-${{ inputs.environment }}` no existe al
      llegar a este step, el job de `apply` falla de forma visible en vez de continuar sin él —
      contracts/plan-artifact-handoff.md, "Qué pasa si el artefacto no existe"
- [ ] T017 [US2] Ejecutar [quickstart.md §2](./quickstart.md) en `dev`: confirmar en el log que el
      step de apply ejecuta `terraform apply ... dev.tfplan` (nunca `-auto-approve -var-file`) y que
      HCP Terraform muestra un solo run para ese cambio, no dos
- [ ] T018 [US2] Ejecutar [quickstart.md §3](./quickstart.md) en `dev` **únicamente**: forzar que un
      plan quede obsoleto antes de aprobar su gate, y confirmar que `apply` falla señalándolo en vez
      de aplicar algo recalculado en su lugar
- [ ] T019 [US2] Ejecutar [quickstart.md §5](./quickstart.md) contra `production`: confirmar que el
      gate de aprobación nativo sigue pausando el job exactamente igual que antes (FR-011), y que
      ahora quien aprueba puede abrir el job `check` de ese mismo run y ver el plan exacto antes de
      aprobar (antes de esta historia, `production` no generaba ningún plan previo — research.md §1)

**Checkpoint**: US2 funcional — el plan aplicado es siempre el revisado, en los tres entornos,
incluyendo `production` por primera vez.

---

## Phase 5: User Story 3 - Incorporar un entorno nuevo sin escribir lógica nueva (Priority: P2)

**Goal**: agregar un entorno (p. ej. un cuarto entorno `qa`) solo requiere archivos de
configuración, nunca lógica de pipeline nueva. **Depende de US1** (necesita que
`terraform-environment.yml` y el patrón de archivo delgado ya existan para poder documentarlo y
demostrarlo).

**Independent Test**: listar qué archivos habría que tocar para dar de alta un entorno nuevo y
confirmar que ninguno es de lógica de recursos ni de pipeline (spec.md, US3).

### Implementation for User Story 3

- [X] T020 [US3] Actualizar `README.md`, sección "Añadir un entorno nuevo": documentar el paso
      nuevo — crear `terraform-apply-<entorno>.yml` que solo invoca `terraform-environment.yml`
      (T004-T007) con su propio `environment` y sus propios secretos — junto a los pasos ya
      existentes (workspace de HCP Terraform, los tres `.tfvars`)
      (contracts/reusable-pipeline-interface.md, "Quién lo invoca")
- [X] T021 [US3] Ejecutar [quickstart.md §6](./quickstart.md) (ejercicio en seco: listar los
      archivos que tocaría un entorno `qa` hipotético) y confirmar que la lista coincide
      exactamente con lo documentado en T020: 3 archivos `.tfvars`, un `terraform-apply-qa.yml`
      delgado, y una línea nueva ("qa") en la validación de `environment_name`
      (`environments/variables.tf`) y en `matrix.environment` de `terraform-pr.yml`/
      `terraform-drift.yml` (valores de enumeración, no lógica — Principio IV) — ningún otro
      contenido de `modules/`, `environments/*.tf` ni `terraform-environment.yml` en esa lista

**Checkpoint**: US3 funcional — el procedimiento para un entorno nuevo está documentado y verificado
contra el diseño real de US1.

---

## Phase 6: User Story 4 - El proveedor nuevo nace sin duplicación (Priority: P3)

**Goal**: cuando se construya el root de Terraform de Azure (fase futura, fuera de alcance aquí),
nace ya siguiendo el patrón de una sola declaración por proveedor. **No depende de ninguna otra
historia de esta fase** — es documentación pura, puede hacerse en cualquier momento.

**Independent Test**: revisar, en el momento en que se cree el primer archivo de recursos de Azure,
que la regla ya estaba documentada y que no existe una copia de ese archivo por entorno (spec.md,
US4).

### Implementation for User Story 4

- [X] T022 [US4] Añadir a `README.md` (sección "Elegir Railway o Azure" o una subsección nueva) la
      regla explícita: el primer archivo de recursos del futuro root de Azure MUST declararse una
      sola vez, variando por entorno mediante `.tfvars` — igual que `environments/` desde ADR 0007
      — citando esta especificación ([research.md §4](./research.md), FR-004). *(Misma archivo que
      T020: no ejecutar en paralelo con esa tarea para evitar un conflicto de edición.)*
- [X] T023 [P] [US4] Revisar `docs/adr/0005-separar-roots-por-proveedor.md` y
      `docs/adr/0007-root-unico-environments.md`; si ninguna deja explícita la obligación de FR-004
      para un proveedor futuro, añadir una nota cruzada hacia esta especificación
      (003-reusable-pipeline-architecture) en ambas

**Checkpoint**: US4 funcional — la regla para el futuro proveedor queda escrita, no solo implícita.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: registrar las decisiones de esta fase como ADR (Principio VIII) y verificar el estado
final de punta a punta.

- [X] T024 [P] Crear `docs/adr/0008-remote-saved-plans-hcp-terraform.md` documentando la decisión de
      research.md §1 (adopción del flujo "Remote Saved Plans"), con el mismo formato ya usado en
      `docs/adr/0004-backend-estado-desacoplado-de-proveedor.md` y
      `docs/adr/0007-root-unico-environments.md`: contexto, decisión, alternativas consideradas,
      consecuencias (incluido el riesgo de *Execution Mode* de T003)
- [X] T025 [P] Crear `docs/adr/0009-workflow-reutilizable-por-entorno.md` documentando la decisión
      de research.md §2 (workflow reutilizable `terraform-environment.yml` + archivos delgados por
      entorno) y la eliminación de `terraform-apply.yml`
- [X] T026 [P] Revisar `docs/runbooks/bootstrap.md` y `docs/runbooks/rollback.md`: si alguno nombra
      `terraform-apply.yml` explícitamente, actualizarlo para referenciar
      `terraform-environment.yml` y los tres archivos delgados (`terraform-apply-dev.yml`,
      `terraform-apply-staging.yml`, `terraform-apply-production.yml`)
- [X] T027 [P] Ejecutar `terraform fmt -check -recursive` sobre `environments/` y confirmar que
      ningún archivo cambió durante esta fase (esta fase solo debía tocar YAML de `.github/`, nunca
      código de Terraform)
- [ ] T028 Ejecutar [quickstart.md](./quickstart.md) completo (secciones 1-6) de punta a punta con
      los tres entornos ya migrados, como verificación final antes de cerrar la fase (depende de
      que T003-T023 estén todas completas)

**Checkpoint**: las cuatro historias quedan funcionando juntas, documentadas como ADR, y verificadas
de punta a punta.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Fase 1)**: sin dependencias — empieza de inmediato.
- **Foundational (Fase 2)**: sin dependencias — empieza de inmediato; **solo bloquea a US2**, no a
  US1, US3 ni US4.
- **US1 (Fase 3)**: depende de Setup (T002); independiente de Foundational y de US2.
- **US2 (Fase 4)**: depende de Setup (T001) y de Foundational (T003); independiente de US1 (ningún
  archivo en común).
- **US3 (Fase 5)**: depende de US1 (T004-T011 deben existir para documentarlos y demostrarlos).
- **US4 (Fase 6)**: sin dependencias de ninguna otra historia; puede hacerse en cualquier momento,
  incluso antes de US1-US3.
- **Polish (Fase 7)**: depende de que US1 y US2 estén completas (documenta sus decisiones); T028
  depende de que todas las fases anteriores estén completas.

### Parallel Opportunities

- T001 y T002 (Setup) en paralelo.
- T008, T009 y T010 (los tres archivos delgados de US1) en paralelo entre sí, una vez completos
  T004-T007.
- US1 (Fase 3) y US2 (Fase 4) son historias completas que se pueden trabajar en paralelo (sin
  archivos en común), siempre que Foundational (T003) ya esté resuelto para quien tome US2.
- US4 (Fase 6) puede trabajarse en paralelo con cualquier otra fase, en cualquier momento.
- T024, T025, T026 y T027 (Polish) en paralelo entre sí; T028 siempre al final.

---

## Parallel Example: User Story 1

```bash
# Una vez creados T004-T007 (terraform-environment.yml), los tres archivos delgados son independientes:
Task: "Crear .github/workflows/terraform-apply-dev.yml"
Task: "Crear .github/workflows/terraform-apply-staging.yml"
Task: "Crear .github/workflows/terraform-apply-production.yml"
```

---

## Implementation Strategy

### MVP First (User Story 1 solamente)

1. Completar Fase 1: Setup.
2. Completar Fase 3: US1 (no depende de la Fase 2).
3. **DETENER Y VALIDAR**: correr quickstart.md §4 — los tres entornos ya son independientes, aunque
   todavía recalculen el plan al aplicar.
4. Esto por sí solo ya es un entorno deployable de forma aislada — el valor central que pidió el
   usuario esta sesión ("un entorno a la vez").

### Entrega incremental

1. Setup + Foundational → listos.
2. US1 → validar con quickstart.md §4 → cada entorno ya es independiente (MVP).
3. US2 → validar con quickstart.md §2/§3/§5 → el plan aplicado ya es siempre el revisado, incluso en
   production.
4. US3 → validar con quickstart.md §6 → el procedimiento de "agregar un entorno" queda documentado
   y probado.
5. US4 → la regla para Azure queda escrita antes de que haga falta.
6. Polish → ADR + runbooks + verificación de punta a punta.

### Nota sobre alcance

Ninguna tarea de esta lista crea o modifica un recurso de Railway o Azure: todo el trabajo vive en
`.github/` y en documentación (`README.md`, `docs/`). `environments/` no se toca (T027 lo confirma).
