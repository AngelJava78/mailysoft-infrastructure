# Implementation Plan: Arquitectura de Referencia — Una Sola Declaración de Recursos y Pipelines Reutilizables por Entorno

**Branch**: `003-reusable-pipeline-architecture` | **Date**: 2026-11-11 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/003-reusable-pipeline-architecture/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Formalizar como regla permanente el patrón ya adoptado para el root de Terraform de Railway (una
sola declaración de recursos, variable por entorno mediante `.tfvars` — ADR 0007) y cerrar la
brecha real que todavía existe en los pipelines de CI/CD de despliegue: hoy `terraform-apply.yml`
encadena dev→staging→production con `needs` (viola FR-008) y su job de `apply` recalcula un plan
nuevo en vez de aplicar el que ya evaluó `check` (viola FR-009/FR-010), y `production` ni siquiera
genera un plan previo antes de aplicar. Enfoque técnico: un workflow reutilizable de GitHub Actions
(`terraform-environment.yml`, `on: workflow_call`, parametrizado por `environment`) concentra el job
graph `check → manual-review (condicional) → apply`, reutilizando sin cambios las dos composite
actions ya existentes; el job `apply` consume el artefacto de plan (`-out=`) que generó su propio
`check`, apoyándose en el mecanismo de "Remote Saved Plans" de HCP Terraform (confirmado contra la
documentación oficial, research.md §1) para que un plan obsoleto se rechace de forma nativa, sin
lógica propia. Tres archivos delgados (uno por entorno, cada uno con su propio disparador filtrado
por ruta) invocan ese workflow sin depender entre sí. El futuro root de Azure (fuera de alcance
construirlo aquí) queda documentado como obligado a nacer con el mismo patrón (FR-004).

## Technical Context

**Language/Version**: Terraform (HCL2) `~> 1.17.x` (sin cambios, ADR 0007); YAML de GitHub Actions
(workflows reutilizables `workflow_call` y composite actions) — sin cambios de versión de ninguna
herramienta, solo de cómo se organiza la lógica ya existente.

**Primary Dependencies**: HCP Terraform (Terraform Cloud), bloque `cloud {}` (ADR 0004) — flujo de
"Remote Saved Plans" del *CLI-driven run workflow* (research.md §1); GitHub Actions *reusable
workflows* (`workflow_call`) y *composite actions* ya existentes (`terraform-apply-env`,
`terraform-check-provider-mix`, sin cambios de interfaz — research.md §2).

**Storage**: N/A — esta fase no añade recursos de datos; el estado de Terraform sigue en HCP
Terraform (ADR 0004, sin cambios).

**Testing**: mismas herramientas ya en uso (`terraform fmt -check`, `terraform validate`, `tflint`,
`checkov`), sin cambios. Se añade a quickstart.md la verificación de extremo a extremo de que (a) el
plan que aplica `apply` es el mismo que generó `check` en la misma invocación, (b) un plan obsoleto
se rechaza en vez de reemplazarse en silencio, y (c) los tres entornos se disparan y ejecutan sin
depender entre sí.

**Target Platform**: GitHub Actions (`ubuntu-latest`) + HCP Terraform, sin cambio de plataforma —
se reorganiza cómo ya se usan, no se sustituyen (Principio V no se reabre).

**Project Type**: Infraestructura como código (IaC) + pipelines de CI/CD, mono-repositorio — mismo
tipo que fases anteriores.

**Performance Goals**: sin cambios respecto a fases anteriores (pipeline completo en <10 min por
entorno); además, desplegar un solo entorno deja de esperar a los demás (hoy dev→staging→production
se ejecutan en secuencia dentro de la misma corrida).

**Constraints**: ningún root de Terraform de un proveedor puede depender del root de otro (FR-003,
ya cierto, se fija como regla permanente); el workspace de HCP Terraform de cada entorno MUST estar
en *Execution Mode* "Local" para que el traspaso de plan entre jobs funcione como lo documenta
HashiCorp — riesgo a verificar antes de depender de él en `production` (research.md §1,
quickstart.md §1); la aprobación nativa de GitHub Environment ya vigente para `production` MUST
seguir intacta (FR-011).

**Scale/Scope**: los 3 entornos ya existentes del root de Railway (dev, staging, production); 3
workflows existentes (`terraform-apply.yml` se sustituye por 3 archivos delgados;
`terraform-pr.yml`/`terraform-drift.yml` sin cambios, research.md §3) y 2 composite actions ya
existentes (sin cambios de interfaz, solo de qué archivo de plan usa `apply`); fija además la regla
que deberá cumplir, desde su primera versión, el futuro root de Azure (fuera de alcance construirlo
en esta fase).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Evaluación | Estado |
|---|---|---|
| I. Propósito y Alcance | Este plan solo reorganiza workflows de CI/CD y la relación entre `check` y `apply`; ningún artefacto toca código de los microservicios ni de las aplicaciones web | PASS |
| II. Multi-Nube con Prioridad Definida | No cambia el proveedor activo de ningún entorno (Railway sigue siendo el único en uso); fija por escrito que el futuro root de Azure MUST seguir el mismo patrón de una sola declaración desde su primera versión (FR-004), reforzando el orden de fases en vez de adelantarlas | PASS |
| III. Terraform como Única Fuente de Verdad | FR-001/FR-002/FR-003 formalizan como regla permanente lo que ADR 0007 ya implementó para Railway; no se duplica ningún módulo ni root | PASS |
| IV. Configuración sobre Código | FR-007 extiende la misma regla ("lo que varía por entorno es dato, no lógica") a la configuración de pipeline, no solo a Terraform | PASS |
| V. Pipelines CI/CD como Único Camino de Despliegue | El orden de etapas exigido (plan → revisión → apply, con aprobación manual en production) no cambia; se corrige que el plan aplicado sea el revisado (FR-009/FR-010) y que cada entorno sea independiente (FR-008), ambos refinamientos del mismo principio, no excepciones a él | PASS |
| VI. Seguridad y Gestión de Secretos | FR-007 reafirma que la configuración de pipeline por entorno nunca contiene el valor de un secreto, solo su referencia; ninguna credencial nueva se introduce | PASS |
| VII. Convenciones de Nomenclatura | Sin impacto: esta fase no crea ni renombra recursos de infraestructura | PASS (no aplica) |
| VIII. Calidad y Documentación | Las decisiones de research.md (adopción de "Remote Saved Plans", diseño del workflow reutilizable) se registran como ADR durante la implementación, igual que en fases anteriores; el README se actualiza con la regla para el futuro root de Azure (research.md §4) | PASS |
| Gobernanza | Ninguna enmienda a la constitución; todas las filas anteriores están en PASS, ninguna excepción que justificar | PASS |

**Re-evaluación post-diseño (tras Fase 1 de este plan)**: sin cambios — data-model.md y contracts/
no introducen ninguna violación nueva. El único riesgo documentado (si el *Execution Mode* de los
workspaces de HCP Terraform no es "Local", el mecanismo de traspaso de plan de research.md §1 podría
no comportarse como lo confirmado contra la documentación) es un riesgo operativo a verificar
(quickstart.md §1), no una violación de ningún principio.

## Project Structure

### Documentation (this feature)

```text
specs/003-reusable-pipeline-architecture/
├── plan.md                              # This file (/speckit-plan command output)
├── research.md                          # Phase 0 output (/speckit-plan command)
├── data-model.md                        # Phase 1 output (/speckit-plan command)
├── quickstart.md                        # Phase 1 output (/speckit-plan command)
├── contracts/                           # Phase 1 output (/speckit-plan command)
│   ├── reusable-pipeline-interface.md
│   └── plan-artifact-handoff.md
└── tasks.md                             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Infraestructura (repository root)

Mismo repositorio de IaC de fases anteriores (Principio I); esta fase reorganiza pipelines de CI/CD
existentes y no introduce ningún tipo de proyecto nuevo:

```text
.github/
├── workflows/
│   ├── terraform-environment.yml        # NUEVO: workflow reutilizable (workflow_call) — el job
│   │                                       graph check → manual-review (condicional) → apply,
│   │                                       una sola vez, parametrizado por "environment"
│   │                                       (contracts/reusable-pipeline-interface.md)
│   ├── terraform-apply-dev.yml           # NUEVO: archivo delgado — solo disparador + parámetros
│   ├── terraform-apply-staging.yml       # NUEVO: archivo delgado — solo disparador + parámetros
│   ├── terraform-apply-production.yml    # NUEVO: archivo delgado — solo disparador + parámetros
│   ├── terraform-apply.yml               # ELIMINADO: sustituido por los 3 archivos anteriores
│   ├── terraform-pr.yml                  # Sin cambios (research.md §3)
│   └── terraform-drift.yml               # Sin cambios (research.md §3)
└── actions/
    ├── terraform-check-provider-mix/     # Mismo contrato de entrada/salida; el plan que genera
    │                                       pasa a subirse como artefacto (antes se descartaba)
    └── terraform-apply-env/              # Cambia de "apply -auto-approve -var-file=..." a
                                            "apply <entorno>.tfplan" sobre el artefacto descargado
                                            (contracts/plan-artifact-handoff.md)

environments/                             # Sin cambios (ADR 0007 ya cumple FR-001/FR-002)

docs/
├── adr/                                   # + ADR: adopción de "Remote Saved Plans" de HCP
│                                             Terraform; + ADR: workflow reutilizable de GitHub
│                                             Actions por entorno (Principio VIII)
└── README.md                              # + regla explícita: el futuro root de Azure MUST nacer
                                              con una sola declaración de recursos por entorno
                                              (research.md §4, FR-004)
```

**Structure Decision**: Se mantiene el mismo repositorio y el mismo root de Terraform de fases
anteriores sin cambios (`environments/`, ya conforme desde ADR 0007); el cambio real de esta fase
vive enteramente en `.github/` — se extrae la lógica ya triplicada en `terraform-apply.yml` a un
único workflow reutilizable, y se reemplazan sus tres jobs encadenados por tres archivos delgados
sin dependencias entre sí, reutilizando sin modificar la interfaz externa de las dos composite
actions ya existentes.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

Ninguna violación de la constitución: todas las filas de la tabla anterior están en PASS. No se
requiere ninguna excepción ni justificación de complejidad adicional.
