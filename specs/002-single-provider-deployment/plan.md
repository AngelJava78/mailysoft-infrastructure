# Implementation Plan: Despliegue de MailySoft en un Solo Proveedor — Railway o Azure (Fase 2 Multi-Nube)

**Branch**: `002-single-provider-deployment` | **Date**: 2026-11-08 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/002-single-provider-deployment/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Convertir Azure en un proveedor de cómputo completo (hoy es un stub que siempre falla) y añadir un
modo "un solo proveedor por entorno" (Railway o Azure) que cubra las dos aplicaciones web, las seis
APIs y la base de datos. Enfoque técnico: reutilizar sin cambios la interfaz común del módulo de
servicio ya definida en la Fase 1 (`domain_type`, `database_connection`, research.md de 001 §1-9);
implementar `modules/service/azure` sobre App Service (las dos apps públicas) y Container Apps con
*Environment* interno (las seis APIs, sin IP pública por construcción); añadir un módulo
`modules/network-domain/azure` (VNet + 2 subredes de cómputo + 1 subred de datos + NSG por subred)
que impone en la red la regla "solo las APIs llegan a la base"; añadir un módulo
`modules/database/railway-managed` (nuevo, para cuando el entorno elige Railway) detrás de la misma
interfaz que ya usa `modules/database/azure-existing`; y un campo nuevo `provider` a nivel de
entorno que las 8 entradas de `services.tfvars` heredan por omisión, con una advertencia explícita
(no un bloqueo) cuando algún servicio se desvía de ese valor. Cada variante de red expone un output
`isolation_guarantee` ("red" en Azure, "credenciales" en Railway) que el pipeline ya existente
imprime junto a la previsualización.

## Technical Context

**Language/Version**: Terraform (HCL2), misma versión fijada en la Fase 1 (`~> 1.15.0`,
research.md de 001 §7); sin cambios en esta fase.

**Primary Dependencies**: provider `terraform-community-providers/railway` (ya en uso, ahora
también para el servicio de Postgres — research.md §3); provider `hashicorp/azurerm` (ya en uso
para el backend de estado y la base de datos existente; se añade su uso para App Service,
Container Apps Environment, Virtual Network, Subnet y Network Security Group — research.md §1-2).

**Storage**: Dos variantes detrás de la misma interfaz de "base de datos del entorno"
(data-model.md): la base ya existente en Azure (`mailysoft-db`, sin cambios respecto a la Fase 1)
cuando el entorno elige Azure, o una base PostgreSQL nueva y propia del entorno en Railway cuando el
entorno elige Railway (research.md §3). Nunca ambas a la vez para el mismo entorno (FR-011/FR-012).

**Testing**: mismas herramientas de la Fase 1 (`terraform fmt -check`, `terraform validate`,
`tflint`, `checkov`), sin cambios. Se añade a `quickstart.md` la verificación de que ninguna API ni
la base de datos responden desde fuera del entorno, en cada proveedor (SC-002), y que la
previsualización declara la garantía de aislamiento activa (SC-006).

**Target Platform**: GitHub Actions (`ubuntu-latest`), sin cambios. El parámetro `provider` del
pipeline (ya existente desde la Fase 1) deja de resolver `azure` como "no disponible" (FR-002).

**Project Type**: Infraestructura como código (IaC) multi-módulo, mono-repositorio — mismo tipo de
proyecto que la Fase 1 (ver Project Structure).

**Performance Goals**: sin cambios respecto a la Fase 1 (pipeline completo en menos de ~10 minutos
por entorno).

**Constraints**: proteger la base de datos ya existente en Azure contra lectura, copia o
destrucción al elegir Railway (FR-012, Principio II); toda API nueva privada por omisión (FR-010);
ninguna de las seis APIs ni la base de datos con acceso público en ningún proveedor (FR-003/FR-004);
riesgo operativo ya aceptado del provider comunitario de Railway (research.md de 001 §1) se extiende
ahora al recurso de Postgres sobre Railway, sin resource de base de datos verificado todavía contra
el esquema real del provider (research.md §3).

**Scale/Scope**: Fase 2 cubre 8 servicios de cómputo (`maily-backoffice`, `maily-frontend`,
`maily-users-api`, `maily-system-api`, `maily-patients-api`, `maily-public-api`,
`maily-clinics-api`, `maily-schedule-api`) × 2 proveedores (Railway, Azure) × 3 entornos, más 1 base
de datos por entorno (externa en Azure o nueva en Railway), con la misma capacidad de crecer solo
por configuración ya exigida en la Fase 1.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Evaluación | Estado |
|---|---|---|
| I. Propósito y Alcance | Este plan solo añade módulos Terraform, configuración y un output de previsualización; ningún artefacto toca el código de los microservicios ni de las dos aplicaciones web (ver Out of Scope del spec) | PASS |
| II. Multi-Nube con Prioridad Definida | Railway sigue siendo el default (data-model.md: `environment.provider` por omisión `railway`); Azure deja de ser stub y pasa a operativo (FR-002); el campo `provider` por servicio sigue existiendo y permite seguir mezclando proveedores si se desea (no se elimina la capacidad, solo se añade una advertencia — FR-014); `mailysoft-db` existente en Azure se sigue tratando como *data source*, nunca recreada (FR-013) | PASS |
| III. Terraform como Única Fuente de Verdad | Los módulos nuevos (`service/azure` real, `network-domain/azure`, `database/railway-managed`) implementan las mismas interfaces comunes ya definidas por tipo de recurso (contracts/); añadir las 3 APIs nuevas y habilitar el frontend es solo configuración sobre `services.tfvars`, sin módulo nuevo por servicio (FR-008/FR-009) | PASS |
| IV. Configuración sobre Código | El nuevo campo `provider` de entorno y el `domain_type` por omisión de las APIs nuevas viven en `.tfvars`, con su propia regla de validación (data-model.md); ningún valor queda hardcodeado en un módulo | PASS |
| V. Pipelines CI/CD | El pipeline ya existente se extiende (no se reemplaza): el parámetro `provider` ya aceptaba `azure` (research.md de 001, pipeline-contract.md), solo deja de producir el error de "no disponible"; se añade la impresión del output `isolation_guarantee` y el gate de aprobación cuando se detecta mezcla de proveedores (FR-014/FR-015) | PASS |
| VI. Seguridad y Secretos | En Azure, cada servicio de cómputo lee sus secretos (`DATABASE_URL`, credenciales de Auth0) desde Key Vault vía Managed Identity (research.md §2), reforzando el mínimo privilegio que ya exige el principio; en Railway, la garantía de aislamiento hacia la base de datos pasa a ser explícitamente de credenciales, no de red, y esa limitación MUST declararse en la previsualización (FR-007) en vez de quedar implícita | PASS |
| VII. Convenciones | Los 8 servicios nuevos/renombrados siguen `mailysoft-<servicio>-<entorno>` (Principio VII); los nombres de servicio que me diste en la conversación (`maily-users-api`, etc.) se traducen a esa convención en `services.tfvars`, documentado como supuesto en spec.md | PASS |
| VIII. Calidad y Documentación | Los módulos nuevos documentan entradas/salidas/ejemplo (contracts/); la elección de Container Apps vs. App Service y la decisión sobre Postgres-en-Railway se registran como ADR (tarea de implementación, igual que se hizo para el provider de Railway en la Fase 1) | PASS |
| Gobernanza | Este plan no modifica la constitución; ninguna desviación requiere excepción formal | PASS |

**Re-evaluación post-diseño (tras Fase 1 de este plan)**: sin cambios — data-model.md y contracts/
no introducen ninguna violación nueva; el único riesgo documentado (resource de Postgres sobre
Railway sin verificar contra el esquema real del provider, research.md §3) es una extensión del
mismo riesgo ya aceptado y mitigado en la Fase 1, no una violación nueva de principio alguno.

## Project Structure

### Documentation (this feature)

```text
specs/002-single-provider-deployment/
├── plan.md                              # This file (/speckit-plan command output)
├── research.md                          # Phase 0 output (/speckit-plan command)
├── data-model.md                        # Phase 1 output (/speckit-plan command)
├── quickstart.md                        # Phase 1 output (/speckit-plan command)
├── contracts/                           # Phase 1 output (/speckit-plan command)
│   ├── network-domain-interface.md
│   ├── database-module-interface.md
│   └── pipeline-contract-delta.md
└── tasks.md                             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Infraestructura (repository root)

Mismo repositorio de IaC de la Fase 1 (Principio I); esta fase añade módulos nuevos y extiende
configuración existente, sin introducir un tipo de proyecto distinto:

```text
modules/
├── service/
│   ├── railway/              # Sin cambios (Fase 1)
│   ├── azure/                 # Deja de ser stub: App Service (apps públicas) + Container Apps
│   │                           #   con Environment interno (las seis APIs) — research.md §1
│   └── aws/                   # Sin cambios: sigue siendo stub (Fase 3, fuera de alcance)
├── database/
│   ├── azure-existing/       # Sin cambios (Fase 1): data source sobre mailysoft-db
│   └── railway-managed/      # Nuevo: servicio de Postgres sobre Railway + volumen, detrás de la
│                               #   misma interfaz que azure-existing (contracts/database-module-interface.md)
├── network-domain/
│   ├── railway/              # Sin cambios de comportamiento; se añade el output isolation_guarantee="credenciales"
│   └── azure/                 # Nuevo: VNet + subred-web + subred-apis + subred-data + NSG por
│                               #   subred; output isolation_guarantee="red" (research.md §2)
└── tags/
    └── common/                # Sin cambios (Fase 1)

environments/
├── dev/
│   ├── environment.tfvars     # + campo nuevo `provider` (default del entorno)
│   ├── services.tfvars         # + 3 APIs nuevas + frontend habilitado; provider heredado del entorno
│   └── database.tfvars         # sin cambios de forma; su `provider` ahora puede ser "railway"
├── staging/                    # Misma forma que dev/
└── production/                 # Misma forma que dev/; apply con aprobación manual (sin cambios)

.github/workflows/
├── terraform-pr.yml            # + impresión del output isolation_guarantee en el comentario de PR
├── terraform-apply.yml         # + gate de aprobación si el plan reporta mezcla de proveedores (FR-014)
└── terraform-drift.yml         # Sin cambios

docs/
├── adr/                        # + ADR: Container Apps vs. App Service para las seis APIs; + ADR:
│                                 #   Postgres sobre Railway sin provider verificado (Principio VIII)
└── runbooks/                   # Sin cambios de forma; rollback.md sigue aplicando igual en ambos proveedores
```

**Structure Decision**: Se extiende el mismo layout de la Fase 1 (`modules/` por tipo de recurso
detrás de interfaz común, `environments/` por entorno) en vez de introducir una estructura nueva.
Ningún módulo de la Fase 1 cambia de forma; `modules/service/azure` pasa de stub a implementación
real sin tocar su interfaz externa (contracts/service-module-interface.md de la Fase 1 sigue
vigente sin cambios), y los dos módulos nuevos (`database/railway-managed`,
`network-domain/azure`) se diseñan detrás de la misma clase de interfaz común que ya exige el
Principio III, documentada en contracts/ de esta feature.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

Ninguna violación de la constitución: todos los gates de la tabla anterior están en PASS. El único
riesgo externo nuevo (recurso de Postgres sobre Railway sin confirmar contra el esquema real del
provider comunitario) se documenta y mitiga en research.md §3, como una extensión del mismo tipo de
riesgo ya aceptado en la Fase 1 para ese mismo provider — no como una excepción nueva a ningún
principio.
