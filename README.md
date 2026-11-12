# mailysoft-infrastructure

Infraestructura como código (IaC) de la plataforma MailySoft. Este repositorio **solo**
despliega infraestructura y pipelines; nunca construye ni modifica el código de los
microservicios (ver [constitution.md](.specify/memory/constitution.md)).

**Fase actual**: Fase 2 de la estrategia multi-nube — Railway **y** Azure operativos como
proveedor único por entorno (ver
[specs/002-single-provider-deployment](specs/002-single-provider-deployment/)); AWS llega en
una fase posterior (Principio II de la constitución).

## Estructura

```text
bootstrap/        # Terraform de un solo uso (estado local) para crear el backend remoto
                   # y el proyecto de Railway — ver docs/runbooks/bootstrap.md
modules/           # Módulos reutilizables por tipo de recurso, por proveedor
environments/      # Un solo root de Terraform (ADR 0007) + datos por entorno en dev/, staging/,
                   # production/ (*.tfvars + backend.hcl, sin código duplicado)
.github/workflows/ # Pipelines de CI/CD (fmt -> validate -> lint -> security-scan -> plan -> apply)
docs/adr/          # Decisiones de arquitectura
docs/runbooks/     # Procedimientos operativos (bootstrap, rollback)
specs/             # Especificación, plan y tareas de esta fase (Spec Kit)
```

## Primeros pasos

1. Ejecutar el bootstrap una sola vez: [docs/runbooks/bootstrap.md](docs/runbooks/bootstrap.md).
2. Completar los valores pendientes (`<...>`) en `environments/<entorno>/*.tfvars` con las
   salidas del bootstrap (ADR 0007: `environments/` es un solo root compartido; cada entorno
   solo aporta datos, no código — el workspace de HCP Terraform de cada uno se selecciona con
   `$env:TF_WORKSPACE`, no con un archivo).
3. Abrir un PR que toque `environments/**` — el pipeline de PR generará automáticamente una
   previsualización (`terraform-pr.yml`).
4. Tras la revisión y el merge, `terraform-apply.yml` aplica a `dev`/`staging`
   automáticamente; `production` requiere aprobación manual en el GitHub Environment del
   mismo nombre.

## Añadir un servicio nuevo

Añadir una entrada al array `services` del `.tfvars` del entorno correspondiente
(`environments/<entorno>/services.tfvars`) — ver el ejemplo comentado en
[environments/dev/services.tfvars.example-new-service](environments/dev/services.tfvars.example-new-service).
**Nunca** requiere tocar nada bajo `modules/` (FR-012 de
[spec.md](specs/001-railway-deployment/spec.md)).

Campos disponibles: ver
[data-model.md](specs/001-railway-deployment/data-model.md) y el contrato de
[modules/service](modules/service/README.md).

## Promover entorno por entorno (dev -> staging -> production)

El pipeline aplica los tres entornos en cada push a `main` que toque `environments/**` o
`modules/**`, pero eso no obliga a desplegar un servicio en los tres a la vez: el campo
`enabled` de cada entrada de `services.tfvars` controla, por servicio y por entorno, si se
crea algo o no (`environments/main.tf`, el root compartido de ADR 0007, filtra las entradas
`enabled` antes de llamar a `modules/service/railway`). Para probar primero en `dev` antes de tocar
`staging`/`production`, dejar `enabled = false` en las entradas de esos entornos hasta
confirmar en `dev`, y recién ahí cambiar a `true` ahí (otro PR, otra previsualización) para
promoverlo.

## Añadir un entorno nuevo

**ADR [0007](docs/adr/0007-root-unico-environments.md)**: `environments/` es un solo root de
Terraform compartido — añadir un entorno nunca copia código, solo datos:

1. Crear en app.terraform.io un workspace `mailysoft-<nuevo-entorno>` (Execution Mode = Local,
   ver [docs/runbooks/bootstrap.md](docs/runbooks/bootstrap.md)), y
   `environments/<nuevo-entorno>/` con `environment.tfvars`, `database.tfvars` y
   `services.tfvars` propios (sin ningún archivo `.tf`: el workspace se selecciona con
   `$env:TF_WORKSPACE = "mailysoft-<nuevo-entorno>"`, no con un archivo).
2. Añadir `<nuevo-entorno>` a la validación de `environment_name` en `environments/variables.tf`
   y a la matriz (`matrix.environment`) de `terraform-pr.yml`/`terraform-drift.yml`.
3. Crear `.github/workflows/terraform-apply-<nuevo-entorno>.yml`: un archivo delgado que solo
   invoca el workflow reutilizable `terraform-environment.yml` con `environment:
   <nuevo-entorno>` y sus propios secretos (ver
   [specs/003-reusable-pipeline-architecture/contracts/reusable-pipeline-interface.md](specs/003-reusable-pipeline-architecture/contracts/reusable-pipeline-interface.md)
   — **ADR [0009](docs/adr/0009-workflow-reutilizable-por-entorno.md)**: ningún entorno nuevo
   agrega lógica de pipeline, solo esta configuración). Si el entorno necesita un gate de
   aprobación (como `production`), crear el GitHub Environment correspondiente con sus reglas de
   protección — `terraform-environment.yml` ya lo activa automáticamente para cualquier entorno
   cuyo nombre tenga reglas configuradas, sin tocar su código.

## Elegir Railway o Azure para un entorno

**ADR [0005](docs/adr/0005-separar-roots-por-proveedor.md)** (2026-11-10, corrige el diseño
original de `002-single-provider-deployment`): el root compartido `environments/` (ADR 0007) es
**100% Railway por construcción** para los tres entornos — no declara el provider `azurerm` ni
referencian ningún módulo de Azure, ni siquiera con `count = 0`. Esto no es una preferencia:
se confirmó contra tres `terraform plan` reales que no existe ninguna combinación de
credenciales de relleno que deje a `azurerm` "inofensivo" cuando está declarado pero sin uso —
Terraform siempre intenta autenticarlo de verdad.

Por eso, elegir Azure para un entorno **ya no es cambiar un único campo** en
`environment.tfvars` — requiere un root de Terraform distinto para ese entorno (que sí
declare `provider "azurerm"` y use el despachador genérico `modules/service`, con sus tres
ramas railway/azure/aws). Ese root todavía no existe en el repositorio porque ningún entorno
lo necesita hoy (los tres están en Railway); los módulos para Azure
(`modules/service/azure`, `modules/database/azure-existing`, `modules/network-domain/azure`)
siguen intactos, listos para cuando haga falta construirlo. El backend de estado también
sigue esa misma separación (ADR [0004](docs/adr/0004-backend-estado-desacoplado-de-proveedor.md)):
HCP Terraform para roots Railway, `azurerm` de `bootstrap/azure-backend` para un futuro root
Azure.

Ver [specs/002-single-provider-deployment/spec.md](specs/002-single-provider-deployment/spec.md)
para el diseño original de FR-001, y el ADR 0005 para la corrección.

**Regla obligatoria para cuando se construya ese root** (ADR 0005 +
[especificación 003](specs/003-reusable-pipeline-architecture/spec.md) FR-004): sus recursos MUST
declararse una sola vez, variando por entorno mediante `.tfvars` — exactamente el patrón que ya
usa `environments/` desde el ADR 0007. El root de Azure MUST nacer así desde su primera versión;
no puede repetirse el error original de `environments/` (una copia de código por entorno) y
corregirlo después.

## Añadir un proveedor nuevo (AWS, Fase 3)

Ver la sección "Añadir un proveedor nuevo" de [modules/service/README.md](modules/service/README.md).
En resumen: un submódulo nuevo bajo `modules/service/<proveedor>/` con la misma interfaz, y
un bloque más en `modules/service/main.tf`. Ningún entorno existente cambia.

## Documentación relacionada

- [Especificación completa](specs/001-railway-deployment/spec.md)
- [Plan de implementación](specs/001-railway-deployment/plan.md)
- [Decisiones técnicas (research.md)](specs/001-railway-deployment/research.md)
- [Guía de validación (quickstart.md)](specs/001-railway-deployment/quickstart.md)
- [ADR 0001: provider comunitario de Railway](docs/adr/0001-railway-terraform-community-provider.md)
- [Runbook de rollback](docs/runbooks/rollback.md)
- [Fase 2 — un solo proveedor por entorno (spec, plan, research, data-model, contracts, quickstart)](specs/002-single-provider-deployment/)
- [ADR 0002: App Service + Container Apps en Azure](docs/adr/0002-azure-compute-choice.md)
- [ADR 0003: Postgres administrado en Railway, riesgo sin verificar](docs/adr/0003-railway-postgres-sin-verificar.md)
- [ADR 0004: backend de estado desacoplado de proveedor](docs/adr/0004-backend-estado-desacoplado-de-proveedor.md)
- [ADR 0005: separar roots por proveedor](docs/adr/0005-separar-roots-por-proveedor.md)
- [ADR 0006: un proyecto de Railway por entorno](docs/adr/0006-un-proyecto-railway-por-entorno.md)
- [ADR 0007: root único en environments/](docs/adr/0007-root-unico-environments.md)
- [Diagramas de despliegue (Railway y Azure)](docs/diagrams/despliegue-mailysoft.html)
