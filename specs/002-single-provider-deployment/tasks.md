---

description: "Task list template for feature implementation"
---

# Tasks: Despliegue de MailySoft en un Solo Proveedor — Railway o Azure (Fase 2 Multi-Nube)

**Input**: Design documents from `/specs/002-single-provider-deployment/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: spec.md no pide explícitamente TDD; las tareas de verificación de cada historia son los
escenarios ejecutables de [quickstart.md](./quickstart.md) (mismo patrón que la Fase 1), no una
suite de pruebas automatizada nueva.

**Organización**: las tareas se agrupan por historia de usuario de [spec.md](./spec.md), en el
mismo orden de prioridad (P1 → P1 → P2 → P2 → P3).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: puede ejecutarse en paralelo (archivo distinto, sin dependencias pendientes)
- **[Story]**: a qué historia de usuario pertenece (US1-US5, spec.md)

## Path Conventions

Repositorio de infraestructura como código (Principio I); no aplican las convenciones de
`src/`/`tests/` de una aplicación. Las rutas de abajo son las de `modules/`, `environments/` y
`.github/workflows/` ya existentes desde la Fase 1 (ver Project Structure de [plan.md](./plan.md)).

## Estado de la implementación (este pase de `/speckit-implement`)

**39 de 49 tareas completas** (todo el código: módulos Terraform, `services.tfvars` ×3
entornos, workflows de GitHub Actions, 2 ADR, READMEs). Las **10 que quedan sin marcar** son
tareas de *verificación* que requieren `terraform`/`tflint`/`checkov` instalados y
credenciales reales de Railway/Azure — ninguno de los dos está disponible en este entorno de
ejecución (sandbox sin acceso a nube), y de todas formas el Principio V prohíbe ejecutar
`apply` contra `staging`/`production` fuera del pipeline. Quedan explícitamente pendientes
de correr en CI o por una persona con acceso: **T019, T020, T023, T024, T025, T030, T038,
T043, T048, T049**. Cada una queda descrita exactamente igual que se planeó; no se inventó
ningún resultado ni se marcaron como hechas sin haberlas corrido.

Dos refinamientos de diseño descubiertos al escribir el código real (no estaban así en
plan.md/data-model.md, documentados en research.md y en los módulos mismos):

1. El *Container Apps Environment* compartido por las seis APIs vive en
   `modules/network-domain/azure` (una vez por entorno), no en `modules/service/azure` (que
   se instancia una vez por servicio) — crearlo ahí habría intentado crear seis entornos.
2. Azure no construye desde un repositorio como Railway: se añadió `container_image` (con un
   valor por omisión derivado de `source_repo`/`source_ref`) porque Azure App
   Service/Container Apps exigen una imagen ya publicada (Principio I: este repositorio nunca
   construye código de aplicación).

El gate de aprobación de FR-014/FR-015 en `dev`/`staging` (T041/T042) quedó implementado en
el workflow, pero **requiere un paso manual de configuración de GitHub** (crear el
`Environment` "manual-review" con *required reviewers*) que esta sesión no puede ejecutar —
mismo tipo de paso que T034 de `001-railway-deployment` dejó manual en su momento.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: confirmar que la cadena de herramientas ya fijada en la Fase 1 cubre los recursos
nuevos de esta fase, antes de tocar ningún módulo.

- [X] T001 Confirmar en `versions.tf` que la versión fijada de `hashicorp/azurerm` soporta
      `azurerm_container_app`, `azurerm_container_app_environment`, `azurerm_subnet` y
      `azurerm_network_security_group`; si no, fijar una versión exacta nueva (nunca un rango
      abierto, Principio III) y actualizar `.terraform.lock.hcl`
- [X] T002 [P] Confirmar que `.tflint.hcl` y `.checkov.yaml` (raíz) ya cubren recursos de red de
      Azure (VNet/Subnet/NSG) y de Container Apps; añadir las reglas que falten

**Checkpoint**: la cadena de herramientas de la Fase 1 queda confirmada para los recursos nuevos.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: cambios de esquema e interfaz de los que dependen las cinco historias de usuario. Sin
este cambio, ninguna historia puede probarse de forma independiente.

**⚠️ CRITICAL**: ninguna historia de usuario puede empezar antes de completar esta fase.

- [X] T003 Añadir el campo `provider` (enum `railway`/`azure`, sin valor por omisión — obligatorio,
      FR-001) a la entidad Entorno: `environments/dev/environment.tfvars`,
      `environments/staging/environment.tfvars` y `environments/production/environment.tfvars`
      (data-model.md, Entidad Entorno)
- [X] T004 En el módulo fachada de servicio (donde hoy vive la lógica de despacho de `var.provider`
      de la Fase 1, T050 de 001-railway-deployment), hacer que `service.provider` sea opcional y
      herede `environment.provider` cuando no se declare explícitamente (data-model.md, Entidad
      Servicio — "nuevo default")
- [X] T005 En el mismo punto de despacho de T004, añadir un bloque `check` (no `variable
      validation`: aquí el requisito es advertir, no bloquear) que compare cada `service.provider`
      y `database.provider` contra `environment.provider` y emita la advertencia de FR-014 listando
      los servicios que se desvían (data-model.md, "Regla nueva de validación cruzada")
- [X] T006 Cambiar el valor por omisión de `domain_type` a `private` para toda entrada de servicio
      de tipo API que no lo declare explícitamente (FR-010; data-model.md, Entidad Servicio)
- [X] T007 [P] Crear `modules/network-domain/azure/variables.tf` y `outputs.tf` implementando la
      interfaz común de [contracts/network-domain-interface.md](./contracts/network-domain-interface.md):
      entradas `environment_name`, `public_service_names`, `private_service_names`,
      `database_requires_isolation`, `tags`; salidas `isolation_guarantee` y `compute_network_refs`
- [X] T008 Implementar `modules/network-domain/azure/main.tf`: una VNet por entorno con las
      subredes `subred-web`, `subred-apis` y `subred-data` (research.md §2); depende de T007
- [X] T009 En `modules/network-domain/azure/main.tf` (depende de T008), crear `nsg-apis` sobre
      `subred-apis` permitiendo entrada solo desde `subred-web` y desde la propia `subred-apis`, y
      denegando cualquier otro origen (research.md §2; FR-005)
- [X] T010 En `modules/network-domain/azure/main.tf` (depende de T008), crear `nsg-data` sobre
      `subred-data` permitiendo entrada solo desde `subred-apis`, y denegando cualquier otro origen,
      incluida `subred-web` (research.md §2; FR-005)
- [X] T011 Fijar `isolation_guarantee = "red"` como salida de `modules/network-domain/azure`
      (depende de T007-T010; contracts/network-domain-interface.md)
- [X] T012 [P] Añadir a `modules/network-domain/railway/outputs.tf` la salida nueva
      `isolation_guarantee`, con valor fijo `"credenciales"` (research.md de 001 §4; sin cambio de
      comportamiento — solo el output nuevo exigido por contracts/network-domain-interface.md)
- [X] T013 [P] Añadir a `modules/database/azure-existing/outputs.tf` la salida nueva `kind`, con
      valor fijo `"referenciada"` (contracts/database-module-interface.md; sin cambio de
      comportamiento sobre el `data source` ya existente)

**Checkpoint**: el esquema de configuración y la interfaz de red/base de datos quedan listos; las
cinco historias pueden empezar (en paralelo si hay capacidad, o en orden de prioridad).

---

## Phase 3: User Story 1 - Elegir un único proveedor para todo un entorno (Priority: P1) 🎯 MVP

**Goal**: que un entorno configurado con `provider = "azure"` despliegue sus dos aplicaciones web y
sus seis APIs en Azure, sin el rechazo de "proveedor no disponible" de la Fase 1.

**Independent Test**: `environments/dev/environment.tfvars` con `provider = "azure"` →
`terraform plan` muestra las ocho aplicaciones sobre recursos de Azure, sin ningún error de
validación (quickstart.md §1).

### Implementation for User Story 1

- [X] T014 [US1] En `modules/service/azure/variables.tf`, quitar el bloque de validación que
      siempre falla ("proveedor no disponible aún", FR-005 de la Fase 1) — el módulo deja de ser
      stub (research.md §1)
- [X] T015 [US1] En `modules/service/azure/main.tf`, implementar la rama de **Azure App Service**
      (Linux, contenedor) para servicios con `domain_type = "public"`, con *Regional VNet
      Integration* saliente hacia la subred `subred-web` recibida por `compute_network_refs`
      (research.md §1; depende de T008)
- [X] T016 [US1] En `modules/service/azure/main.tf` (mismo archivo que T015, no paralelizable),
      implementar la rama de **Azure Container Apps**: un *Container Apps Environment* con
      integración de VNet en `subred-apis` (`compute_network_refs`) y, por cada servicio con
      `domain_type = "private"`, una *Container App* con `ingress.external = false` (research.md
      §1; FR-004; depende de T008)
- [X] T017 [US1] Actualizar `modules/service/azure/outputs.tf` para devolver `public_url` (solo
      cuando aplica la rama de T015) e `internal_address` (rama de T016), con la misma forma que ya
      exige contracts/service-module-interface.md de la Fase 1 (sin cambios de esa interfaz)
- [X] T018 [US1] En `environments/dev/main.tf`, pasar `compute_network_refs` de
      `modules/network-domain/azure` (T007-T011) a cada instancia de `modules/service/azure`
      (T015-T017)
- [ ] T019 [US1] Verificar quickstart.md §1 contra `dev` con `provider = "azure"`: `terraform plan`
      incluye las ocho aplicaciones sobre Azure y `isolation_guarantee = "red"`, sin error de
      "proveedor no disponible"
- [ ] T020 [US1] Verificar regresión: repetir quickstart.md §1 con `provider = "railway"` en `dev` y
      confirmar que el comportamiento de la Fase 1 sigue intacto (Principio II: ninguna fase
      posterior rompe una fase ya entregada)

**Checkpoint**: elegir Railway o Azure como proveedor único de un entorno ya es una operación de
configuración, no de código — MVP de esta fase alcanzado.

---

## Phase 4: User Story 2 - Mantener las APIs y la base de datos fuera del alcance de internet (Priority: P1)

**Goal**: que ninguna de las seis APIs ni la base de datos respondan desde fuera del entorno, en
ningún proveedor.

**Independent Test**: tras desplegar `dev` en cada proveedor, ninguna URL de API ni de la base de
datos responde desde fuera (quickstart.md §2-3).

### Implementation for User Story 2

- [X] T021 [US2] Auditar `environments/*/services.tfvars` y `environments/*/main.tf`: confirmar que
      `database_connection`/`secret_refs` de la base de datos solo se pasan a servicios con
      `requires_database = true` (las seis APIs), nunca a `maily-backoffice` ni a `maily-frontend`
      (FR-006; mismo patrón de auditoría que T045 de 001-railway-deployment)
- [X] T022 [US2] Confirmar que ninguna entrada de API en `environments/*/services.tfvars` quedó con
      `domain_type = "public"` por error, ahora que T006 cambió el valor por omisión (FR-003/FR-004)
- [ ] T023 [US2] Verificar quickstart.md §2 contra `dev` en Azure: ninguna de las seis APIs ni
      `maily-db` resuelven un dominio público
- [ ] T024 [US2] Verificar quickstart.md §2 contra `dev` en Railway: mismo resultado que T023,
      confirmando que la garantía se sostiene aunque el mecanismo (research.md §4) sea distinto
- [ ] T025 [US2] Verificar quickstart.md §3 contra `dev` en Azure: una conexión de prueba lanzada
      desde `subred-web` hacia el puerto de `maily-db` es rechazada por `nsg-data` (T010)

**Checkpoint**: las dos aplicaciones web siguen siendo la única puerta de entrada pública, en los
dos proveedores, con evidencia de red (Azure) y de configuración (Railway).

---

## Phase 5: User Story 3 - Incorporar las APIs nuevas de la plataforma (Priority: P2)

**Goal**: añadir `maily-clinics-api`, `maily-schedule-api`, `maily-public-api` y habilitar
`maily-frontend`, solo con configuración.

**Independent Test**: añadir una entrada nueva a `services.tfvars` y confirmar que el plan solo
agrega esa API, sin tocar los servicios ya desplegados (quickstart.md §4).

### Implementation for User Story 3

- [X] T026 [P] [US3] Añadir a `environments/dev/services.tfvars` la entrada
      `mailysoft-clinicas-api-dev` (nombre de origen `maily-clinics-api`), sin declarar
      `domain_type` para que tome el valor por omisión `private` de T006 (data-model.md, tabla de
      servicios nuevos)
- [X] T027 [P] [US3] Añadir a `environments/dev/services.tfvars` la entrada
      `mailysoft-agenda-api-dev` (nombre de origen `maily-schedule-api`), mismo patrón que T026
- [X] T028 [P] [US3] Añadir a `environments/dev/services.tfvars` la entrada
      `mailysoft-publica-api-dev` (nombre de origen `maily-public-api`), mismo patrón que T026, con
      `requires_database = true` (solo lectura)
- [X] T029 [US3] En `environments/dev/services.tfvars`, cambiar `mailysoft-web-dev.enabled` de
      `false` a `true` (es la entrada ya existente desde la Fase 1 para `maily-frontend`, FR-009;
      data-model.md, "La entrada `mailysoft-web-<entorno>` ya existe...")
- [ ] T030 [US3] Verificar quickstart.md §4: el plan resultante de T026-T029 solo agrega/habilita
      las cuatro entradas nuevas, sin ningún `update`/`replace`/`delete` sobre los servicios ya
      desplegados
- [X] T031 [US3] Replicar T026-T029 en `environments/staging/services.tfvars` y
      `environments/production/services.tfvars` una vez validado en `dev`

**Checkpoint**: la plataforma completa (8 aplicaciones) queda representada en la configuración de
cada entorno.

---

## Phase 6: User Story 4 - Aprovisionar la base de datos sin arriesgar la que ya existe (Priority: P2)

**Goal**: que elegir Railway aprovisione una base de datos nueva y propia del entorno, sin tocar
`mailysoft-db` en Azure.

**Independent Test**: desplegar `dev` con `provider = "railway"` y confirmar que el plan no incluye
ninguna acción sobre el recurso de Azure (quickstart.md §5).

### Implementation for User Story 4

- [X] T032 [P] [US4] Crear `modules/database/railway-managed/variables.tf` y `outputs.tf`
      implementando la interfaz común de
      [contracts/database-module-interface.md](./contracts/database-module-interface.md)
      (`environment_name`, `database_name`, `connection_secret_ref` → `database_connection`, `kind`)
- [X] T033 [US4] Implementar `modules/database/railway-managed/main.tf`: un `railway_service` desde
      la imagen oficial de Postgres con SSL de Railway, más un volumen de Railway para persistencia
      (research.md §3; depende de T032)
- [X] T034 [US4] Fijar `kind = "administrada"` como salida de `modules/database/railway-managed`
      (depende de T032-T033)
- [X] T035 [US4] Añadir, al inicio de `modules/database/railway-managed/README.md`, la misma
      advertencia de verificación pendiente que `modules/service/railway/README.md` de la Fase 1:
      confirmar contra `registry.terraform.io` el recurso de volumen persistente antes del primer
      `apply` real (research.md §3, riesgo sin verificar)
- [X] T036 [US4] En `environments/dev/main.tf`, hacer que la selección de módulo de base de datos
      (`azure-existing` vs. `railway-managed`) dependa únicamente de `environment.provider` (T003),
      nunca de una variable independiente (contracts/database-module-interface.md, "Selección de
      variante")
- [X] T037 [US4] Confirmar que `modules/database/railway-managed` no declara ninguna referencia,
      `data source` ni dependencia hacia los recursos de `modules/database/azure-existing` (FR-012)
- [ ] T038 [US4] Verificar quickstart.md §5 contra `dev` con `provider = "railway"`: el plan crea el
      servicio y el volumen nuevos en Railway, e `isolation_guarantee = "credenciales"`; ninguna
      acción del plan referencia `mailysoft-db` en Azure

**Checkpoint**: Railway y Azure quedan como alternativas completas e independientes también para la
base de datos, sin riesgo cruzado entre ambas.

---

## Phase 7: User Story 5 - Ver qué tanto aislamiento impone cada proveedor antes de aprobar (Priority: P3)

**Goal**: que la previsualización de cualquier cambio declare si el aislamiento API↔base es garantía
de red o solo de credenciales.

**Independent Test**: generar una previsualización en cada proveedor y confirmar que el texto
distingue el tipo de garantía (quickstart.md §6; spec.md US5).

### Implementation for User Story 5

- [X] T039 [US5] En `environments/dev/main.tf` (y luego `staging`/`production`), exponer
      `isolation_guarantee` como output raíz del entorno, tomado del módulo
      `network-domain` activo (T011/T012)
- [X] T040 [US5] En `.github/workflows/terraform-pr.yml`, añadir un paso que lea
      `terraform output isolation_guarantee` y lo incluya en el comentario/artefacto del plan ya
      publicado (contracts/pipeline-contract-delta.md, "Salidas observables")
- [X] T041 [US5] En `.github/workflows/terraform-apply.yml`, añadir el gate de aprobación cuando el
      plan reporte la advertencia de mezcla de proveedores de T005 (FR-014), tratándolo como el
      mismo tipo de gate que un cambio destructivo, en cualquier entorno (contracts/pipeline-contract-delta.md)
- [X] T042 [US5] En el mismo workflow de T041, añadir el gate de aprobación cuando el plan reemplace
      todos los servicios y la base de datos de un entorno por un cambio de `environment.provider`
      (FR-015)
- [ ] T043 [US5] Verificar quickstart.md §6: forzar `maily-system-api` con `provider = "azure"` en un
      entorno configurado como `provider = "railway"` y confirmar la advertencia explícita y el gate
      de aprobación; revertir el cambio de prueba

**Checkpoint**: nadie aprueba un cambio sin saber, explícitamente, qué garantía de aislamiento
aplica en ese proveedor.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: documentación y verificación final que afecta a toda la fase, no a una sola historia.

- [X] T044 [P] Documentar en `docs/adr/0002-azure-compute-choice.md` la decisión de App Service
      (apps públicas) + Container Apps con *Environment* interno (APIs) frente a las alternativas
      descartadas (research.md §1; Principio VIII)
- [X] T045 [P] Documentar en `docs/adr/0003-railway-postgres-sin-verificar.md` la decisión de
      modelar Postgres sobre Railway como `railway_service` + volumen, y el riesgo sin verificar
      contra el esquema real del provider (research.md §3; Principio VIII)
- [X] T046 [P] Documentar entradas, salidas y un ejemplo de uso en el `README.md` de cada módulo
      nuevo o cambiado: `modules/service/azure/`, `modules/network-domain/azure/`,
      `modules/database/railway-managed/` (Principio VIII)
- [X] T047 [P] Actualizar el README raíz con los pasos para activar Azure como proveedor de un
      entorno (ya no es "fase futura") y para aprovisionar la base de datos en Railway
- [ ] T048 Ejecutar íntegramente [quickstart.md](./quickstart.md) de principio a fin contra `dev`,
      en los dos proveedores, dejando el entorno en el estado que tenía antes de empezar
- [ ] T049 Auditar que ningún secreto (credenciales de `maily-db`, claves de Managed Identity)
      aparece en el repositorio, en `services.tfvars`/`database.tfvars` ni en los logs del pipeline,
      en los dos proveedores (FR-016; mismo patrón que T062 de 001-railway-deployment)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias — puede empezar de inmediato
- **Foundational (Phase 2)**: depende de Setup — BLOQUEA las cinco historias de usuario
- **Historias de usuario (Phase 3-7)**: todas dependen de que Foundational esté completa
  - US1 no depende de ninguna otra historia (usa directamente T007-T013 de Foundational)
  - US2 depende de que US1 haya dejado operativo `modules/service/azure` (T014-T018) para poder
    verificar el aislamiento en Azure; en Railway puede verificarse sin esperar a US1
  - US3 es independiente de US1/US2/US4/US5 (solo configuración)
  - US4 depende de Foundational (T003, T013) pero no de US1/US2/US3
  - US5 depende de que exista `isolation_guarantee` en los módulos de red (Foundational T011/T012)
    y se beneficia de que US1 y US4 ya estén probadas para tener algo que previsualizar en los dos
    proveedores, pero su propio código (T039-T042) no depende de ellas para implementarse
- **Polish (Phase 8)**: depende de que las historias que se quieran entregar ya estén completas

### Parallel Opportunities

- T001-T002 (Setup) en paralelo
- Dentro de Foundational: T007 puede iniciarse en paralelo con T003/T006; T012 y T013 son
  independientes entre sí y del resto de Foundational
- Dentro de US3: T026-T028 son archivos/entradas distintas del mismo `services.tfvars` pero no
  dependen una de otra — tratarlas como ediciones secuenciales del mismo archivo en la práctica,
  aunque conceptualmente independientes
- Dentro de US4: T032 bloquea a T033-T034 (mismo módulo); documentación (T035) es paralela al resto
- Toda la Phase 8 (T044-T047) en paralelo entre sí; T048-T049 al final, tras cerrar las historias

---

## Implementation Strategy

### MVP First (User Story 1 solamente)

1. Completar Phase 1 (Setup) y Phase 2 (Foundational) — bloquean todo lo demás
2. Completar Phase 3 (US1): Azure deja de ser stub
3. **Parar y validar**: `terraform plan` contra `dev` en Azure, sin errores (quickstart.md §1)
4. Esto ya responde la pregunta central de la conversación de origen: "todo en Railway o todo en
   Azure" es una operación de configuración

### Entrega incremental

1. Setup + Foundational → base lista
2. + US1 → Azure operativo como alternativa completa (MVP)
3. + US2 → verificado que ninguna API/base responde desde internet en ningún proveedor
4. + US3 → las 3 APIs nuevas y el frontend quedan representados
5. + US4 → Railway también puede alojar la base de datos, sin tocar la de Azure
6. + US5 → la previsualización deja de ocultar qué garantía de aislamiento aplica
7. Cada incremento es desplegable y demostrable por separado, sin romper el anterior

## Notes

- [P] = archivos distintos o ediciones independientes, sin dependencias pendientes
- Cada historia debe poder completarse y probarse de forma independiente (quickstart.md)
- Confirmar que `terraform plan` no reporta cambios inesperados antes de cada `apply`
- Hacer commit después de cada tarea o grupo lógico de tareas
- Revertir cualquier configuración de prueba (T020, T024-T025, T043) antes de continuar
