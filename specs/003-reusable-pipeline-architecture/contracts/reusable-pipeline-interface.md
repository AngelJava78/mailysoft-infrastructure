# Contrato: Workflow reutilizable de despliegue por entorno (`terraform-environment.yml`)

**Spec**: [spec.md](../spec.md) | **Research**: [research.md](../research.md) §1-2

Este contrato describe la interfaz del workflow reutilizable de GitHub Actions
(`on: workflow_call`) que concentra, una sola vez, la lógica de despliegue de un entorno (FR-006).
Cualquier entorno — los tres actuales y cualquiera futuro (FR-012) — se despliega invocando este
contrato, nunca copiando su lógica.

## Entrada

| Nombre | Tipo | Obligatorio | Descripción |
|---|---|---|---|
| `environment` (input) | string | sí | `dev`, `staging` o `production`. Único dato que distingue una invocación de otra (FR-007); determina el `TF_WORKSPACE` (`mailysoft-<environment>`), las rutas de `.tfvars` a usar, y el nombre del GitHub Environment que se declara en el job `apply` |
| `azure-client-id`, `azure-tenant-id`, `azure-subscription-id` (secrets) | string | sí | mismos secretos ya usados hoy; solo tienen efecto si `environment.tfvars` de ese entorno resuelve `environment_provider = "azure"` |
| `railway-token` (secret) | string | sí | token de Railway propio de ESE entorno (p. ej. `RAILWAY_TOKEN_DEV`); nunca un token compartido entre entornos |
| `tfc-token` (secret) | string | sí | token de API de HCP Terraform (ADR 0004); puede ser el mismo para los tres entornos, dado que HCP Terraform aísla por `TF_WORKSPACE`, no por token |
| `tf-version` (input) | string | sí | versión fijada de Terraform (Principio III); hoy `1.17.1` |

## Comportamiento garantizado (postcondiciones)

| Garantía | Requisito que satisface |
|---|---|
| Ejecuta, en este orden, `check` (plan de solo lectura) → `manual-review` (solo si `check` marca `requires_review = true`) → `apply` | Principio V (orden de etapas), FR-010/FR-014 |
| El job `apply` aplica el artefacto de plan que generó el propio job `check` de esta misma invocación; nunca recalcula un plan nuevo | FR-009 (contracts/plan-artifact-handoff.md) |
| El job `apply` declara `environment: ${{ inputs.environment }}`; cuando ese nombre de entorno tiene reglas de protección configuradas en GitHub (hoy, solo `production`), el job se pausa hasta la aprobación nativa, sin ninguna condición adicional en este workflow | FR-011 |
| Ninguna etapa cambia de contenido según el valor de `environment`; solo cambian los valores que ese parámetro inyecta (rutas de `.tfvars`, `TF_WORKSPACE`, secretos) | FR-006/FR-007 |
| Esta invocación no inicia, espera ni se bloquea por ninguna otra invocación de este mismo workflow para un `environment` distinto | FR-008 (lo garantiza quien invoca — ver "Quién lo invoca" — no este workflow en sí) |

## Quién lo invoca

Tres archivos delgados, cada uno con su propio disparador y sin dependencias (`needs`) entre ellos:

| Archivo | Dispara con | `environment` |
|---|---|---|
| `terraform-apply-dev.yml` | `push` a `main` que toque `environments/dev/**` o los archivos compartidos del root (`environments/*.tf`, `modules/**`) | `dev` |
| `terraform-apply-staging.yml` | `push` a `main` que toque `environments/staging/**` o los archivos compartidos del root | `staging` |
| `terraform-apply-production.yml` | `push` a `main` que toque `environments/production/**` o los archivos compartidos del root | `production` |

Un cambio exclusivo de `environments/dev/services.tfvars` MUST disparar únicamente
`terraform-apply-dev.yml`. Un cambio en `environments/main.tf` (compartido) MUST disparar los tres,
porque de verdad afecta a los tres (FR-002 — es dato compartido, no una excepción a FR-008).

## Fuera de este contrato

- La vista previa de pull request (`terraform-pr.yml`) y la detección de drift
  (`terraform-drift.yml`) no invocan este workflow en esta fase (research.md §3); siguen su propio
  mecanismo de matriz ya existente.
- Este contrato no define qué credencial usa cada entorno (eso es `environments/<entorno>/environment.tfvars`
  más los secretos del repositorio) — solo cómo el pipeline las recibe.
