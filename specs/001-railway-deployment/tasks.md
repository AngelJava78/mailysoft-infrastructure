---

description: "Task list template for feature implementation"
---

# Tasks: Despliegue Automatizado de MailySoft en Railway (Fase 1 Multi-Nube)

**Input**: Design documents from `/specs/001-railway-deployment/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md (todos presentes)

**Tests**: No se generan tareas de pruebas dedicadas (TDD) porque ni el spec ni el usuario las
solicitaron explícitamente. Cada historia incluye en su lugar tareas de verificación operativa que
reproducen su "Independent Test" del spec, consistente con la naturaleza de un repositorio de IaC.

**Organization**: Las tareas se agrupan por historia de usuario (spec.md) para permitir
implementación y prueba independientes de cada una.

**Estado de implementación (2026-10-24)**: 39/62 tareas completadas — todo el código Terraform
(módulos, bootstrap, entornos), los tres workflows de GitHub Actions y toda la documentación
(ADR, runbooks, READMEs). Las 23 tareas restantes requieren credenciales/cuentas reales
(Azure, Railway, GitHub) que no estaban disponibles en la sesión que generó este código, o
requieren ejecutar Terraform (sin CLI instalada en esa sesión): aprovisionar el backend real
(T006-T010), toda ejecución en vivo del pipeline (T027, T028, T032, T033, T038, T039, T042,
T046, T048, T051, T052, T055, T056, T061), crear el GitHub Environment `production` (T034),
y la parte de "logs de pipeline" de la auditoría de secretos (T062, la parte de repositorio
sí se verificó). Ver `docs/runbooks/bootstrap.md` para el procedimiento que desbloquea el
resto.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Puede ejecutarse en paralelo (archivos distintos, sin dependencias pendientes)
- **[Story]**: Historia de usuario a la que pertenece (US1-US8, según spec.md)
- Se incluye la ruta de archivo exacta en cada descripción

## Path Conventions

Repositorio de infraestructura como código (no aplicación): rutas bajo `modules/`,
`environments/<entorno>/`, `.github/workflows/` y `docs/`, según la estructura fijada en
[plan.md](./plan.md#project-structure).

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Inicialización del repositorio y herramientas base

- [X] T001 Crear la estructura de directorios base: `modules/`, `environments/dev/`,
  `environments/staging/`, `environments/production/`, `bootstrap/azure-backend/`,
  `bootstrap/railway-project/`, `.github/workflows/`, `docs/adr/`, `docs/runbooks/`, según
  [plan.md](./plan.md#project-structure)
- [ ] T002 Crear `versions.tf` en la raíz fijando `required_version = "~> 1.15.0"` (confirmar patch
  exacto contra releases.hashicorp.com) y las versiones exactas de los providers
  `terraform-community-providers/railway` y `hashicorp/azurerm` (research.md §7); generar y
  commitear `.terraform.lock.hcl`
- [X] T003 [P] Configurar `.tflint.hcl` en la raíz con el ruleset de Terraform y reglas de
  convención de nombres `mailysoft-<servicio>-<entorno>` (research.md §8, Principio VII de la
  constitución)
- [X] T004 [P] Configurar `.checkov.yaml` en la raíz con la línea base de políticas de seguridad
  para Terraform (research.md §8)
- [X] T005 [P] Actualizar `.gitignore` para excluir `.terraform/`, `*.tfstate*`, `*.tfplan` y
  cualquier archivo de credenciales locales

**Checkpoint**: Estructura y herramientas base listas.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Infraestructura y módulos compartidos que TODAS las historias necesitan

**⚠️ CRITICAL**: Ninguna historia de usuario puede empezar hasta completar esta fase.

- [ ] T006 Crear `bootstrap/azure-backend/main.tf` — Terraform de un solo uso con **estado local**
  (única excepción admisible al Principio III: el backend remoto aún no existe) que aprovisiona la
  Storage Account de Azure + 3 contenedores Blob (`tfstate-dev`, `tfstate-staging`,
  `tfstate-production`) con versionado y cifrado en reposo habilitados; ejecutarlo una sola vez y
  documentar el procedimiento en `docs/runbooks/bootstrap.md` (research.md §6, Principio III)
- [ ] T007 [P] Añadir a `bootstrap/azure-backend/oidc.tf` los recursos `azuread_application`,
  `azuread_service_principal` y `azurerm_federated_identity_credential` que configuran la
  federación OIDC entre el repositorio GitHub y Microsoft Entra ID, con asignaciones de rol de
  mínimo privilegio sobre la Storage Account y el Key Vault (research.md §2, Principio VI)
- [ ] T008 [P] Añadir a `bootstrap/azure-backend/keyvault.tf` el recurso `azurerm_key_vault` y el
  contenedor `azurerm_key_vault_secret` para la conexión de `mailysoft-db`; fijar el valor real del
  secreto mediante una única acción de datos (`az keyvault secret set`, nunca commiteada) descrita
  en `docs/runbooks/bootstrap.md` (research.md §2, FR-011)
- [ ] T009 [P] Crear `bootstrap/railway-project/main.tf` con los recursos `railway_project` y
  `railway_environment` (dev/staging/production) del provider comunitario, aplicado una sola vez
  con un Account Token de uso exclusivo para este bootstrap (nunca usado por el pipeline); emitir
  después, desde Railway, un *Project Token* por entorno para uso exclusivo del pipeline
  (research.md §3)
- [ ] T010 Guardar cada *Project Token* de Railway (T009) como secreto **de repositorio** con
  nombre por entorno (no de GitHub Environment — ver research.md §2 sobre por qué) mediante
  `gh secret set RAILWAY_TOKEN_DEV` / `RAILWAY_TOKEN_STAGING` / `RAILWAY_TOKEN_PRODUCTION`
  (research.md §2, Principio VI; depende de T009)
- [X] T011 [P] Implementar el módulo fachada `modules/service/variables.tf` y
  `modules/service/outputs.tf` según [contracts/service-module-interface.md](./contracts/service-module-interface.md)
- [X] T012 [P] Implementar `modules/service/railway/` (implementación operativa de esta fase) según
  contracts/service-module-interface.md y research.md §1, §3, §4
- [X] T013 [P] Implementar el stub `modules/service/azure/` que falla la validación con el mensaje
  explícito "proveedor no disponible aún" según contracts/service-module-interface.md (FR-005)
- [X] T014 [P] Implementar el stub `modules/service/aws/` con el mismo patrón que T013
  (contracts/service-module-interface.md, FR-005)
- [X] T015 [P] Implementar `modules/database/azure-existing/` (solo `data` source de lectura sobre
  `mailysoft-db`, sin ningún `resource` de escritura) según data-model.md §"Recurso de base de
  datos externo" (FR-006)
- [X] T016 [P] Implementar `modules/network-domain/railway/` (Public Networking / Private
  Networking + dominio personalizado) según research.md §4
- [X] T017 [P] Implementar `modules/tags/common/` (convención de nombres + variables de
  introspección `TAG_PROYECTO`, `TAG_SERVICIO`, `TAG_ENTORNO`, `TAG_PROPIETARIO`,
  `TAG_GESTIONADO_POR`) según research.md §5 (Principio VII)
- [X] T018 [P] Crear `environments/dev/backend.tf` y `environments/dev/providers.tf` apuntando al
  contenedor `tfstate-dev` (depende de T006)
- [X] T019 [P] Crear `environments/staging/backend.tf` y `environments/staging/providers.tf`
  apuntando al contenedor `tfstate-staging` (depende de T006)
- [X] T020 [P] Crear `environments/production/backend.tf` y `environments/production/providers.tf`
  apuntando al contenedor `tfstate-production` (depende de T006)

**Checkpoint**: Backend de estado, autenticación, módulos base y proyecto de Railway listos — las
historias de usuario pueden empezar.

---

## Phase 3: User Story 1 - Desplegar toda la plataforma en Railway sin pasos manuales (Priority: P1) 🎯 MVP

**Goal**: Que los 4 servicios activos de MailySoft queden desplegados en el entorno `dev` de
Railway ejecutando únicamente el pipeline, sin ningún paso manual en la consola.

**Independent Test**: Ejecutar el pipeline contra `dev` desde cero y confirmar que, al finalizar,
los servicios configurados quedan operativos en Railway sin haber usado su consola web.

- [X] T021 [P] [US1] Crear `environments/dev/environment.tfvars` (campos de la entidad "Entorno":
  `name = "dev"`, `railway_project_id`, `region_hint` — data-model.md)
- [X] T022 [P] [US1] Crear `environments/dev/database.tfvars` referenciando `mailysoft-db` (campos
  de "Recurso de base de datos externo": `provider = "azure"`, `resource_id`,
  `connection_secret_ref` — data-model.md)
- [X] T023 [P] [US1] Crear `environments/dev/services.tfvars` con 5 entradas de servicio:
  `mailysoft-usuarios-api-dev`, `mailysoft-pacientes-api-dev`, `mailysoft-sistema-api-dev` y
  `mailysoft-backoffice-dev` con `enabled = true, provider = "railway"`, y
  `mailysoft-web-dev` con `enabled = false` (data-model.md §"Servicio", FR-001, FR-002)
- [X] T024 [US1] Crear `environments/dev/main.tf` instanciando `modules/service` por cada entrada
  habilitada de `services.tfvars` y `modules/database/azure-existing` una vez (depende de
  T021-T023 y de los módulos de la Fase 2)
- [X] T025 [US1] Crear `.github/workflows/terraform-pr.yml` ejecutando, en este orden, `fmt -check`
  → `validate` → `tflint` → `checkov` → `plan`, disparado en pull requests que modifiquen
  `environments/**` o `modules/**` (contracts/pipeline-contract.md)
- [X] T026 [US1] Crear `.github/workflows/terraform-apply.yml` ejecutando `apply` tras el merge a
  `main` para `dev` (sin gate de aprobación todavía; se añade en US3) (contracts/pipeline-contract.md)
- [ ] T027 [US1] Ejecutar el flujo completo (PR → merge → apply) contra `dev` y confirmar, siguiendo
  [quickstart.md](./quickstart.md) pasos 1-3, que los 4 servicios habilitados quedan desplegados sin
  ningún paso manual en la consola de Railway (SC-001)
- [ ] T028 [US1] Volver a ejecutar `terraform plan -detailed-exitcode` contra `dev` sin cambios
  intermedios y confirmar código de salida `0` (idempotencia — quickstart.md paso 5, SC-005, FR-016)

**Checkpoint**: `dev` completamente desplegado y verificado de forma independiente.

---

## Phase 4: User Story 2 - Previsualizar cambios antes de aplicarlos (Priority: P1)

**Goal**: Que toda propuesta de cambio genere una previsualización revisable, con los cambios
destructivos señalados explícitamente, antes de que pueda aplicarse nada.

**Independent Test**: Proponer un cambio de configuración y confirmar que el sistema genera una
previsualización legible de ese cambio antes de que exista cualquier posibilidad de aplicarlo.

> Depende de que el pipeline básico de US1 (T025) ya exista; esta historia lo extiende.

- [X] T029 [US2] En `terraform-pr.yml`, añadir un paso que ejecute `terraform show -json` sobre el
  plan generado y detecte acciones `delete`/`replace` (contracts/pipeline-contract.md, FR-010)
- [X] T030 [US2] En `terraform-pr.yml`, publicar el resumen legible del plan como comentario o
  artefacto del pull request, asegurando que ningún valor de `secret_refs` aparezca en texto plano
  (FR-008, FR-011)
- [X] T031 [US2] Cuando T029 detecte acciones `delete`/`replace`, marcar el comentario/artefacto del
  PR con una advertencia explícita de "cambio destructivo" (FR-010)
- [ ] T032 [US2] Verificar: modificar una variable de un servicio de `dev` en un PR y confirmar que
  la previsualización aparece antes de cualquier aplicación (quickstart.md paso 2)
- [ ] T033 [US2] Verificar: proponer `enabled = false` para un servicio ya desplegado en `dev` y
  confirmar que el PR resultante señala explícitamente la eliminación como cambio destructivo (Edge
  Case "deshabilitar un servicio habilitado" del spec)

**Checkpoint**: Ningún cambio llega a `dev` sin pasar primero por una previsualización revisable.

---

## Phase 5: User Story 3 - Exigir aprobación para desplegar a producción (Priority: P1)

**Goal**: Que ningún cambio se aplique sobre `production` sin la aprobación manual explícita de un
responsable técnico.

**Independent Test**: Proponer un cambio hacia `production` y confirmar que el pipeline se detiene
en un punto de aprobación explícita antes de aplicarlo.

> Depende del pipeline de US1 (T026) y del mecanismo de previsualización de US2.

- [ ] T034 [US3] Crear el GitHub Environment `production` con regla de protección de "required
  reviewers" (al menos un responsable técnico) (FR-009)
- [X] T035 [US3] Actualizar `terraform-apply.yml` para que el job de `apply` contra `production` se
  ejecute dentro del GitHub Environment `production`, quedando pausado hasta su aprobación
  (contracts/pipeline-contract.md)
- [X] T036 [P] [US3] Crear `environments/production/environment.tfvars`,
  `environments/production/database.tfvars` y `environments/production/services.tfvars`
  (mismo contenido que `dev`, replicando los 4 servicios habilitados — FR-003)
- [X] T037 [US3] Crear `environments/production/main.tf` (mismo patrón que `dev`, contra el backend
  `tfstate-production`; depende de T036)
- [ ] T038 [US3] Verificar: proponer un cambio hacia `production` y confirmar que el job de `apply`
  queda detenido esperando aprobación manual antes de aplicarse (FR-009)
- [ ] T039 [US3] Verificar: aprobar el cambio como responsable técnico y confirmar que el `apply`
  procede solo después de esa aprobación (FR-009)

**Checkpoint**: MVP completo — US1 + US2 + US3 cubren el flujo seguro de despliegue descrito en el
spec como valor central de esta fase.

---

## Phase 6: User Story 4 - Mantener entornos separados (Priority: P2)

**Goal**: Que dev, staging y production operen de forma aislada, sin que un cambio en uno afecte a
otro.

**Independent Test**: Desplegar el mismo conjunto de servicios con configuraciones distintas en
`dev` y `staging`, y confirmar que un cambio en `dev` no modifica recursos de `staging` ni de
`production`.

- [X] T040 [P] [US4] Crear `environments/staging/environment.tfvars`,
  `environments/staging/database.tfvars`, `environments/staging/services.tfvars` y
  `environments/staging/main.tf` (mismo patrón que `dev`/`production`, backend `tfstate-staging`)
  (FR-003)
- [X] T041 [US4] Confirmar que `environments/dev`, `environments/staging` y
  `environments/production` usan contenedores de estado remoto distintos y no se solapan
  (research.md §6)
- [ ] T042 [US4] Verificar: aplicar un cambio de configuración solo en
  `environments/dev/services.tfvars` y confirmar que `terraform plan` en `staging` y `production`
  no reporta ningún cambio (Acceptance Scenario de US4)

**Checkpoint**: Los tres entornos conviven de forma aislada y verificable.

---

## Phase 7: User Story 5 - Conectar servicios en Railway a la base de datos existente en Azure (Priority: P2)

**Goal**: Que las APIs desplegadas en Railway se conecten correctamente a `mailysoft-db` sin que el
pipeline la cree, modifique ni destruya.

**Independent Test**: Desplegar una API que requiere base de datos y confirmar que se conecta a
`mailysoft-db` usando solo datos de conexión referenciados por configuración, sin que el pipeline
intente crearla, modificarla o destruirla.

- [X] T043 [US5] En `modules/database/azure-existing`, exponer el output de datos de conexión
  (host, puerto, referencia al secreto) leyendo el secreto desde Azure Key Vault (T008), marcado
  `sensitive = true` en Terraform (FR-006, FR-011)
- [X] T044 [US5] En `environments/dev/services.tfvars`, marcar `requires_database = true` para
  `mailysoft-usuarios-api-dev` y `mailysoft-pacientes-api-dev`, e inyectar en `main.tf` la
  referencia al output de T043 (FR-007; depende de T043)
- [X] T045 [US5] Auditar todos los módulos del repositorio y confirmar que ninguno declara un
  `resource` de escritura sobre `mailysoft-db` (solo `data` sources) — invariante de data-model.md
  (FR-006)
- [ ] T046 [US5] Verificar conectividad end-to-end: ejecutar el paso 4 de
  [quickstart.md](./quickstart.md) contra `mailysoft-pacientes-api-dev` y confirmar que resuelve la
  variable de conexión y alcanza `mailysoft-db` (SC-006)

**Checkpoint**: Las APIs de `dev` leen y escriben contra la base de datos real de Azure sin riesgo
de recrearla.

---

## Phase 8: User Story 6 - Añadir una nueva API solo con configuración (Priority: P2)

**Goal**: Que incorporar una nueva API requiera únicamente agregar su configuración, sin duplicar
ni modificar las definiciones de las APIs existentes.

**Independent Test**: Agregar la configuración de una API ficticia nueva y confirmar que, tras la
aprobación, queda desplegada igual que las demás, sin haber tocado ningún módulo existente.

- [X] T047 [US6] Añadir una entrada de servicio ficticia nueva (p. ej. `mailysoft-ejemplo-api-dev`)
  únicamente en `environments/dev/services.tfvars`, sin modificar ningún archivo bajo `modules/`
  (FR-012)
- [ ] T048 [US6] Ejecutar `terraform-pr.yml` sobre ese cambio y confirmar que la previsualización
  solo muestra la creación del nuevo servicio, sin ninguna modificación sobre los servicios ya
  existentes (Acceptance Scenario de US6)
- [ ] T049 [US6] Eliminar la entrada ficticia de `services.tfvars` tras la verificación, dejando
  `dev` en su configuración real (limpieza)

**Checkpoint**: Queda demostrado que crecer en número de APIs no requiere tocar `modules/`.

---

## Phase 9: User Story 7 - Elegir el proveedor de destino por configuración (Priority: P3)

**Goal**: Que el proveedor de cada servicio/entorno sea seleccionable por configuración, y que
elegir Azure o AWS en esta fase produzca un mensaje claro de "no disponible aún" en vez de un fallo
inesperado.

**Independent Test**: Cambiar el proveedor declarado de un servicio a "Azure" o "AWS" y confirmar
que el sistema responde con un mensaje explícito de "no disponible aún", sin aplicar ningún cambio
parcial.

- [X] T050 [US7] En `modules/service` (fachada), añadir la lógica de despacho que lee `var.provider`
  y selecciona el submódulo correspondiente (`railway`, `azure`, `aws`) según
  contracts/service-module-interface.md
- [ ] T051 [US7] Verificar: configurar temporalmente un servicio de prueba en `dev` con
  `provider = "azure"` y confirmar que `terraform validate`/`plan` falla con el mensaje explícito
  "proveedor no disponible aún", sin aplicar ningún cambio parcial (FR-005)
- [ ] T052 [US7] Revertir la configuración de prueba a `provider = "railway"` y confirmar que el
  mismo servicio se despliega normalmente (Acceptance Scenario de US7)

**Checkpoint**: La selección de proveedor por configuración queda probada en ambos sentidos
(disponible / no disponible aún).

---

## Phase 10: User Story 8 - Detectar diferencias entre la infraestructura real y la definida (Priority: P3)

**Goal**: Detectar cuándo la infraestructura real en Railway difiere de la configuración definida,
reportándolo para revisión humana sin corregirlo automáticamente de forma destructiva.

**Independent Test**: Modificar manualmente un recurso directamente en Railway (fuera del pipeline)
y confirmar que una ejecución de detección de drift reporta esa diferencia sin corregirla
automáticamente.

- [X] T053 [US8] Crear `.github/workflows/terraform-drift.yml` con un cron diario por entorno que
  ejecute `terraform plan -detailed-exitcode -lock=false` en modo solo lectura (research.md §9,
  FR-015)
- [X] T054 [US8] En `terraform-drift.yml`, cuando el código de salida sea `2`, abrir o actualizar un
  issue de GitHub describiendo el recurso afectado, sin aplicar ningún cambio (FR-015)
- [ ] T055 [US8] Verificar: modificar manualmente una variable de un servicio desde el dashboard de
  Railway en `dev` (solo para esta prueba) y confirmar que la siguiente ejecución de
  `terraform-drift.yml` lo reporta (quickstart.md paso 6)
- [ ] T056 [US8] Revertir el cambio manual aplicando de nuevo la configuración versionada, dejando
  `dev` consistente otra vez (quickstart.md paso 6, cierre)

**Checkpoint**: Todas las historias de usuario del spec quedan implementadas y verificadas de forma
independiente.

---

## Phase 11: Polish & Cross-Cutting Concerns

**Purpose**: Documentación y validación final que abarca todas las historias

- [X] T057 [P] Documentar en `docs/adr/0001-railway-terraform-community-provider.md` la decisión y
  los riesgos del provider comunitario de Railway, con sus mitigaciones (research.md §1, Principio
  VIII)
- [X] T058 [P] Escribir `docs/runbooks/rollback.md` con el procedimiento de rollback (`git revert`/
  checkout del último estado estable + flujo plan→revisión→apply) (FR-013, research.md §9)
- [X] T059 [P] Escribir el README raíz con los pasos concretos para añadir un servicio, añadir un
  entorno y (en una fase futura) añadir un proveedor (FR-014, Principio VIII)
- [X] T060 [P] Documentar entradas, salidas y un ejemplo de uso en un `README.md` por módulo:
  `modules/service/README.md`, `modules/database/azure-existing/README.md`,
  `modules/network-domain/railway/README.md`, `modules/tags/common/README.md` (Principio VIII)
- [ ] T061 Ejecutar íntegramente [quickstart.md](./quickstart.md) de principio a fin contra `dev`
  como validación final de SC-001 a SC-006
- [ ] T062 Auditar que ningún secreto aparece en el repositorio ni en los logs del pipeline,
  revisando el historial de commits y los logs de las últimas ejecuciones de `terraform-pr.yml` y
  `terraform-apply.yml` (SC-004, FR-011)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Fase 1)**: sin dependencias — puede iniciarse de inmediato
- **Foundational (Fase 2)**: depende de completar Setup — bloquea todas las historias de usuario
- **User Stories (Fases 3-10)**: todas dependen de completar Foundational
  - US1, US2 y US3 (todas P1) tienen una dependencia secuencial intencional: US2 extiende el
    pipeline que US1 crea; US3 extiende tanto el pipeline de US1 como el mecanismo de
    previsualización de US2. Juntas forman el MVP (ver spec.md, "Why this priority" de US3).
  - US4, US5 y US6 (P2) son independientes entre sí y de US7/US8; cada una solo depende de
    Foundational + de que `dev` ya exista (US1)
  - US7 y US8 (P3) son independientes entre sí; cada una solo depende de Foundational
- **Polish (Fase 11)**: depende de que todas las historias deseadas estén completas

### User Story Dependencies

- **US1 (P1)**: depende solo de Foundational
- **US2 (P1)**: depende de Foundational + del pipeline básico creado en US1 (T025)
- **US3 (P1)**: depende de Foundational + US1 (T026) + US2 (mecanismo de previsualización)
- **US4 (P2)**: depende de Foundational + de que `dev` exista (US1), para replicar su patrón
- **US5 (P2)**: depende de Foundational + de que `dev` y sus servicios existan (US1)
- **US6 (P2)**: depende de Foundational + US1 (para tener un entorno donde probar la adición)
- **US7 (P3)**: depende solo de Foundational (usa `dev` como entorno de prueba, pero no de otras
  historias)
- **US8 (P3)**: depende de Foundational + de que `dev` tenga servicios desplegados (US1)

### Within Each User Story

- Configuración (`.tfvars`) antes de `main.tf`
- `main.tf` antes de ejecutar el pipeline contra ese cambio
- Implementación antes de la verificación operativa (tareas de "Verificar: ...")
- Historia completa antes de pasar a la siguiente en el plan de entrega incremental

### Parallel Opportunities

- Todas las tareas de Setup marcadas [P] pueden ejecutarse en paralelo
- Dentro de Foundational, T007-T009 (OIDC, Key Vault, proyecto Railway) y T011-T020 (módulos y
  backends por entorno) pueden ejecutarse en paralelo entre sí (archivos/recursos distintos)
- Una vez completado Foundational, US4, US5, US6, US7 y US8 pueden trabajarse en paralelo por
  distintas personas, siempre que US1 ya haya creado `dev`
- US2 y US3 deben respetar su orden secuencial respecto a US1 (ver dependencias arriba)

---

## Parallel Example: Foundational

```bash
# Lanzar en paralelo los módulos independientes de la Fase 2:
Task: "Implementar modules/service/railway/ según contracts/service-module-interface.md"
Task: "Implementar el stub modules/service/azure/ (FR-005)"
Task: "Implementar el stub modules/service/aws/ (FR-005)"
Task: "Implementar modules/database/azure-existing/ (FR-006)"
Task: "Implementar modules/network-domain/railway/ (research.md §4)"
Task: "Implementar modules/tags/common/ (research.md §5)"
```

## Parallel Example: User Story 1

```bash
# Lanzar en paralelo los tres archivos de configuración de dev:
Task: "Crear environments/dev/environment.tfvars"
Task: "Crear environments/dev/database.tfvars"
Task: "Crear environments/dev/services.tfvars"
```

---

## Implementation Strategy

### MVP First (User Stories 1 + 2 + 3)

1. Completar Fase 1: Setup
2. Completar Fase 2: Foundational (CRÍTICO — bloquea todas las historias)
3. Completar Fase 3 (US1): `dev` desplegado sin pasos manuales
4. Completar Fase 4 (US2): previsualización obligatoria con cambios destructivos señalados
5. Completar Fase 5 (US3): aprobación manual obligatoria en `production`
6. **DETENERSE Y VALIDAR**: las tres historias juntas son el MVP descrito en el spec

### Incremental Delivery

1. Setup + Foundational → base lista
2. US1 → `dev` funcional de extremo a extremo (demo posible)
3. US2 → ningún cambio llega sin previsualización (refuerza seguridad operativa)
4. US3 → `production` protegido por aprobación manual (MVP completo)
5. US4 → `staging` y aislamiento de entornos verificado
6. US5 → conectividad a la base de datos de pacientes verificada en profundidad
7. US6 → extensibilidad (nueva API) verificada
8. US7 → selección de proveedor por configuración verificada (prepara Fase 2 Azure)
9. US8 → detección de drift verificada
10. Polish → documentación, ADR, runbook de rollback y validación final de criterios de éxito

### Parallel Team Strategy

Con varias personas disponibles:

1. El equipo completa Setup + Foundational en conjunto
2. Una persona avanza US1 → US2 → US3 (secuencial, es el MVP)
3. En paralelo, otras personas pueden avanzar US4, US5, US6, US7 y US8 en cuanto `dev` (US1) exista
4. Polish se reparte entre quienes terminen primero

---

## Notes

- [P] = archivos distintos, sin dependencias pendientes
- La etiqueta [US#] asocia cada tarea con su historia de usuario del spec, para trazabilidad
- No se crearon tareas de prueba TDD dedicadas: la verificación de cada historia se apoya en su
  "Independent Test" del spec y en quickstart.md
- Cometer (`git commit`) tras cada tarea o grupo lógico de tareas
- Detenerse en cada checkpoint para validar la historia de forma independiente antes de continuar
- Evitar: tareas vagas, conflictos de archivo entre tareas paralelas, dependencias cruzadas entre
  historias que rompan su independencia (salvo la dependencia secuencial US1→US2→US3, explícita y
  documentada arriba)
