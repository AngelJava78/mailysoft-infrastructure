# Data Model: Arquitectura de Referencia — Una Sola Declaración de Recursos y Pipelines Reutilizables por Entorno

**Spec**: [spec.md](./spec.md) | **Research**: [research.md](./research.md)

Esta especificación no introduce entidades de infraestructura nuevas (ningún recurso de Railway o
Azure). Las entidades de este documento son estructurales: describen cómo se organiza el código de
Terraform y de pipelines para cumplir FR-001 a FR-012, no datos que viajen en tiempo de ejecución.

## Entidad: Root de Terraform por proveedor

Conjunto único de archivos `.tf` que declara los recursos de un proveedor (Railway hoy; Azure y AWS
en fases futuras, Principio II). Nunca se copia por entorno.

| Campo | Tipo | Obligatorio | Regla de validación |
|---|---|---|---|
| `proveedor` | enum | sí | `railway` (único existente hoy); `azure`, `aws` reservados para fases futuras (FR-004) |
| `archivos_de_recursos` | list(path) | sí | exactamente un conjunto por proveedor; FR-001 prohíbe que exista más de una copia para distintos entornos |
| `archivos_de_configuración_por_entorno` | map(entorno → list(path)) | sí | datos (`.tfvars`), nunca lógica (`.tf`); FR-002 |

**Estado actual**: el root de Railway (`environments/`) ya cumple esta entidad desde
[ADR 0007](../../docs/adr/0007-root-unico-environments.md) — no cambia en esta fase. No existe todavía
un root de Azure (Out of Scope); cuando se cree, MUST instanciar esta misma entidad desde su primera
versión (FR-004, research.md §4).

## Entidad: Lógica reutilizable de pipeline

La definición única de las etapas de integración y despliegue continuo de un entorno, independiente
de cuál sea ese entorno.

| Campo | Tipo | Obligatorio | Regla de validación |
|---|---|---|---|
| `nombre` | string | sí | `terraform-environment.yml` (único; research.md §2) |
| `etapas` | list(enum) | sí | `check` (plan de solo lectura + evaluación FR-010/FR-014), `manual-review` (condicional), `apply` (con el artefacto de plan de `check`, nunca uno recalculado — FR-009) |
| `parámetro_de_entrada` | string | sí | `environment`; único dato que distingue una invocación de otra (FR-007) |

**Invariante** (FR-006): ninguna etapa de esta entidad MUST tener una variante distinta por entorno.
Si una etapa necesita comportarse distinto para un entorno (p. ej. `production` sin `manual-review`
incondicional porque ya tiene su propio gate), esa diferencia MUST expresarse con el valor del
parámetro de entrada (`environment`) y con la configuración nativa de la plataforma de CI/CD
(Entornos de GitHub, ver abajo), nunca con una copia de la etapa.

## Entidad: Configuración de pipeline por entorno

La unidad mínima de datos que activa la lógica reutilizable para un entorno específico.

| Campo | Tipo | Obligatorio | Regla de validación |
|---|---|---|---|
| `entorno` | enum | sí | `dev`, `staging`, `production` (mismo dominio que `environment_name` en Terraform) |
| `disparador` | config de CI/CD | sí | filtrado por las rutas propias de ese entorno + los archivos compartidos del root (research.md §2); MUST NOT disparar el pipeline de un entorno por un cambio exclusivo de otro |
| `credenciales` | referencia a secreto | sí | nunca el valor del secreto (Principio VI); una referencia distinta por entorno (p. ej. `RAILWAY_TOKEN_DEV` vs. `RAILWAY_TOKEN_STAGING`) |
| `ubicación_de_estado` | string | sí | `TF_WORKSPACE = mailysoft-<entorno>` (ADR 0004/0007); nunca lógica adicional |

**Invariante** (FR-007/FR-012): esta entidad MUST NOT contener pasos ni condicionales que no existan
ya en la Lógica reutilizable de pipeline. Agregar un entorno nuevo MUST significar crear una
instancia nueva de esta entidad (y de la configuración de Terraform ya exigida por
`environment.tfvars`/`database.tfvars`/`services.tfvars`), nunca una etapa nueva.

## Entidad: Artefacto de plan

El resultado de generar un plan para un entorno y un cambio dados, en el sentido de HCP Terraform
("remote saved plan" — research.md §1): una referencia, no un archivo de plan completo y portátil.

| Campo | Tipo | Obligatorio | Regla de validación |
|---|---|---|---|
| `entorno` | enum | sí | el mismo que generó el plan |
| `estado` | enum (gestionado por HCP Terraform) | — | `vigente` mientras el estado real del entorno no cambie después de generarse; `obsoleto` en cuanto algo más se aplique a ese mismo entorno (detectado y descartado automáticamente, research.md §1) |
| `consumidor` | referencia | sí | el job `apply` de la misma invocación de `terraform-environment.yml` que lo generó; FR-009 prohíbe que `apply` use un artefacto distinto al que generó su propio `check` |

**Invariante** (FR-009/FR-010): un artefacto de plan `obsoleto` MUST NOT aplicarse. Cuando ocurra,
el pipeline MUST señalarlo y exigir una ejecución nueva (que generará un artefacto nuevo), nunca
sustituirlo en silencio por un recálculo.

## Relaciones

```text
Root de Terraform por proveedor ──declara recursos de──> (ninguna entidad de este documento; ver
                                                           data-model.md de fases anteriores)

Lógica reutilizable de pipeline ──se invoca con──> Configuración de pipeline por entorno
                                                           │
                                                           ▼
                                              genera ──> Artefacto de plan ──consumido por──> etapa apply
                                                           (misma invocación, nunca otra)
```
