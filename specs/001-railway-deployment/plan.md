# Implementation Plan: Despliegue Automatizado de MailySoft en Railway (Fase 1 Multi-Nube)

**Branch**: `001-railway-deployment` | **Date**: 2026-10-24 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-railway-deployment/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Desplegar y gestionar toda la infraestructura de MailySoft (3 APIs, backoffice, frontend futuro y
la referencia a la base de datos PostgreSQL de Azure) en Railway de forma 100% declarativa con
Terraform, sin pasos manuales en consola, como primera fase de una estrategia multi-nube
(Railway → Azure → AWS). El enfoque técnico: módulos Terraform organizados por tipo de recurso
(servicio, base de datos, red/dominio) detrás de una interfaz común por proveedor (research.md
§1-6), configuración por entorno en `.tfvars` (dev/staging/production), pipelines de GitHub
Actions que aplican el flujo fmt→validate→lint→security-scan→plan→revisión→apply con aprobación
manual obligatoria en production, y un backend de estado remoto en Azure Storage separado por
entorno. La base de datos de Azure se referencia como recurso externo (`data source`), nunca se
gestiona como recurso creable/destruible.

## Technical Context

**Language/Version**: Terraform (HCL2), `required_version = "~> 1.15.0"` (confirmar patch exacto
contra releases.hashicorp.com al implementar — research.md §7)

**Primary Dependencies**: provider `terraform-community-providers/railway` (pinned, sin provider
oficial — research.md §1), provider `hashicorp/azurerm` (backend de estado, Key Vault, data
source de la base de datos existente), GitHub Actions (`hashicorp/setup-terraform`,
`azure/login@v2` con OIDC)

**Storage**: Estado de Terraform en Azure Storage Account (backend `azurerm`), un contenedor Blob
por entorno (research.md §6). La única base de datos de aplicación es `mailysoft-db`
(PostgreSQL en Azure), referenciada como recurso externo, no administrada por este repositorio.

**Testing**: `terraform fmt -check`, `terraform validate`, `tflint` (lint), `checkov` (análisis de
seguridad) — research.md §8. Validación funcional end-to-end vía los escenarios de
[quickstart.md](./quickstart.md) (equivalente a pruebas de integración en un repositorio de IaC).

**Target Platform**: GitHub Actions (`ubuntu-latest`) orquestando despliegues hacia Railway; Azure
se usa en esta fase solo para el backend de estado, Key Vault y la base de datos ya existente.

**Project Type**: Infraestructura como código (IaC) multi-módulo, mono-repositorio — no es una
aplicación con frontend/backend propios (ver Project Structure más abajo, estructura dedicada en
lugar de las opciones genéricas de app del template).

**Performance Goals**: el pipeline completo (fmt→validate→lint→security-scan→plan) por entorno
MUST completarse en menos de ~10 minutos para no degradar el flujo de revisión de PRs (valor por
defecto razonable, sin número exigido por el spec).

**Constraints**: idempotencia (FR-016, SC-005); cero secretos en repositorio/logs/preview
(FR-011, SC-004); prohibido crear/modificar recursos manualmente (Principio I/III); servicios
desplegados en la región de Railway más cercana a la región de Azure de `mailysoft-db` (FR-017);
riesgo operativo aceptado y mitigado del provider comunitario de Railway (research.md §1).

**Scale/Scope**: Fase 1 cubre 5 servicios (`mailysoft-usuarios-api`, `mailysoft-pacientes-api`,
`mailysoft-sistema-api`, `mailysoft-backoffice`, `mailysoft-web` deshabilitado hasta que exista su
código) × 3 entornos (dev/staging/production) + 1 referencia externa a base de datos, con
capacidad de crecer solo por configuración (FR-012).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Evaluación | Estado |
|---|---|---|
| I. Propósito y Alcance | El plan solo produce módulos Terraform, configuración y pipelines; ningún artefacto toca código de los microservicios (ver Out of Scope del spec) | PASS |
| II. Multi-Nube con Prioridad Definida | Fase 1 = Railway completo; `provider` es un campo de configuración por servicio/entorno (data-model.md); los módulos `azure`/`aws` existen como stubs que fallan de forma explícita (contracts/service-module-interface.md); `mailysoft-db` se referencia, nunca se recrea (research.md §1,3) | PASS |
| III. Terraform como Única Fuente de Verdad | 100% Terraform; versión de CLI y providers fijadas exactamente (research.md §7); estado remoto en Azure con bloqueo y cifrado, separado por entorno (research.md §6); módulos organizados por tipo de recurso detrás de interfaz común (contracts/service-module-interface.md); añadir una API = añadir configuración, no módulo nuevo (data-model.md) | PASS (riesgo externo documentado y mitigado en research.md §1: provider comunitario de Railway) |
| IV. Configuración sobre Código | Todo lo variable vive en `.tfvars` por entorno (data-model.md); validación de variables vía bloques `validation` de Terraform | PASS |
| V. Pipelines CI/CD | GitHub Actions con fmt→validate→lint→security-scan→plan→revisión→apply (contracts/pipeline-contract.md); PR solo ejecuta plan; apply en production requiere aprobación manual; drift detection programado; rollback documentado (research.md §9) | PASS |
| VI. Seguridad y Secretos | Secretos en GitHub Secrets/Environments + Azure Key Vault, nunca en texto plano (FR-011); OIDC para Azure; Railway usa Project Tokens acotados a un entorno porque el proveedor no ofrece OIDC (excepción explícitamente permitida por el propio texto del principio: "donde el proveedor lo permita") — research.md §2 | PASS |
| VII. Convenciones | Nombres `mailysoft-<servicio>-<entorno>`; las 5 etiquetas obligatorias se codifican como convención de nombres + variables de introspección + Terraform state, dado que Railway no soporta tags nativas (research.md §5) | PASS (mecanismo alternativo documentado, no es una omisión) |
| VIII. Calidad y Documentación | Cada módulo documentará entradas/salidas/ejemplo (contracts/service-module-interface.md como base); README raíz con pasos para añadir servicio/entorno/proveedor (tarea de implementación); decisión del provider de Railway registrada como ADR (tarea de implementación); cambios destructivos señalados explícitamente en el plan (contracts/pipeline-contract.md) | PASS |
| Gobernanza | Este plan no modifica la constitución; ninguna desviación requiere excepción formal | PASS |

**Re-evaluación post-diseño (tras Fase 1)**: sin cambios — el diseño en data-model.md y
contracts/ no introduce ninguna violación nueva; todos los gates permanecen en PASS.

## Project Structure

### Documentation (this feature)

```text
specs/001-railway-deployment/
├── plan.md                              # This file (/speckit-plan command output)
├── research.md                          # Phase 0 output (/speckit-plan command)
├── data-model.md                        # Phase 1 output (/speckit-plan command)
├── quickstart.md                        # Phase 1 output (/speckit-plan command)
├── contracts/                           # Phase 1 output (/speckit-plan command)
│   ├── service-module-interface.md
│   └── pipeline-contract.md
└── tasks.md                             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Infraestructura (repository root)

Este repositorio no contiene una aplicación con frontend/backend propios (Principio I); es un
repositorio de infraestructura como código. La estructura refleja los módulos por tipo de recurso
y la configuración por entorno exigidos por los Principios III y IV:

```text
bootstrap/                   # Terraform de un solo uso para el problema del huevo y la gallina
├── azure-backend/            # Crea el backend remoto (Storage Account + Key Vault + OIDC) con estado LOCAL
└── railway-project/          # Crea el proyecto/entornos de Railway con un Account Token de un solo uso

modules/
├── service/                 # Módulo "fachada": interfaz común (contracts/service-module-interface.md)
│   ├── railway/              # Implementación operativa en esta fase
│   ├── azure/                 # Stub: falla con "proveedor no disponible aún" (FR-005)
│   └── aws/                   # Stub: falla con "proveedor no disponible aún" (FR-005)
├── database/
│   └── azure-existing/       # Data source sobre mailysoft-db; nunca un "resource" de escritura
├── network-domain/
│   └── railway/              # Public/Private Networking + dominio personalizado (research.md §4)
└── tags/
    └── common/                # Convención de nombres + variables de introspección (research.md §5)

environments/
├── dev/
│   ├── backend.tf             # Backend azurerm, contenedor tfstate-dev
│   ├── providers.tf
│   ├── main.tf                 # Instancia los módulos por cada entrada de services.tfvars
│   ├── environment.tfvars
│   ├── services.tfvars
│   └── database.tfvars
├── staging/                    # Misma forma que dev/, backend en tfstate-staging
└── production/                 # Misma forma que dev/, backend en tfstate-production; apply con aprobación manual

.github/workflows/
├── terraform-pr.yml            # fmt → validate → lint → security-scan → plan (solo PRs)
├── terraform-apply.yml         # Flujo completo hasta apply; gate manual en production
└── terraform-drift.yml         # Cron diario por entorno; abre issue si detecta drift

docs/
├── adr/                        # Decisiones de arquitectura (Principio VIII), ej. provider de Railway
└── runbooks/
    └── rollback.md             # Procedimiento de rollback (FR-013, research.md §9)
```

**Structure Decision**: Se usa un layout de repositorio IaC dedicado (no las opciones
src/tests o backend/frontend del template, que asumen una aplicación). `modules/` agrupa cada
tipo de recurso detrás de una interfaz común por proveedor (contracts/service-module-interface.md);
`environments/` aísla configuración y estado por entorno (data-model.md); los workflows de
`.github/workflows/` implementan el contrato descrito en contracts/pipeline-contract.md.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

Ninguna violación de la constitución: todos los gates de la tabla anterior están en PASS. El
único riesgo externo relevante (provider comunitario de Railway, sin alternativa oficial) queda
documentado y mitigado en research.md §1, no como una excepción a un principio sino como una
limitación del ecosistema del proveedor aceptada dentro de los límites que la constitución permite.
