# Quickstart: Validar la arquitectura de referencia (root único + pipelines reutilizables)

**Spec**: [spec.md](./spec.md) | **Data model**: [data-model.md](./data-model.md) | **Contracts**: [contracts/](./contracts/)

Esta guía valida que cada entorno se despliega sin arrastrar a los demás (SC-002), que el plan
aplicado es siempre el revisado (SC-003), que un entorno nuevo solo necesitaría configuración
(SC-001), y que la aprobación manual sigue siendo la nativa de GitHub (SC-005). No repite la
validación de FR-001/FR-002 para el root de Terraform de Railway: ya se hizo al confirmar
[ADR 0007](../../docs/adr/0007-root-unico-environments.md) y no cambia en esta fase.

## Prerrequisitos

- Acceso de administrador al repositorio en GitHub (para inspeccionar runs y Environments).
- Acceso a la organización de HCP Terraform `angel-java` (para inspeccionar el *Execution Mode* de
  los workspaces — ver advertencia de contracts/plan-artifact-handoff.md).
- Ejecutar primero en `dev`; no repetir en `staging`/`production` hasta que el paso 2 confirme que
  el traspaso de plan funciona como se espera (contracts/plan-artifact-handoff.md).

## 1. Confirmar el *Execution Mode* del workspace antes de depender del traspaso de plan

En HCP Terraform → workspace `mailysoft-dev` → Settings → General → **Execution Mode**.

**Resultado esperado**: `Local` — así se documentó al adoptar HCP Terraform
([ADR 0004](../../docs/adr/0004-backend-estado-desacoplado-de-proveedor.md), 2026-11-09); este paso
solo reconfirma que sigue siendo así. Si dice `Remote` o `Agent`, el riesgo documentado en
research.md §1 aplica sin confirmar; cambiarlo a `Local` antes de continuar, o detener aquí y tratar
este hallazgo como un bloqueador de implementación, no solo una nota.

## 2. Verificar que `check` y `apply` comparten el mismo plan (FR-009)

Tras implementar `terraform-environment.yml` (contracts/reusable-pipeline-interface.md), disparar
un cambio trivial y no destructivo únicamente en `dev` (p. ej. una etiqueta nueva en
`environments/dev/services.tfvars`) y revisar el run resultante en GitHub Actions:

**Resultado esperado**:

- El job `check` sube el artefacto `tfplan-dev`.
- El job `apply` lo descarga y ejecuta `terraform apply tfplan-dev.tfplan` (visible en el log del
  step; MUST NOT aparecer `-auto-approve -var-file=`).
- En HCP Terraform, el workspace `mailysoft-dev` muestra **un solo run** para este cambio (el que
  generó `check`, confirmado como aplicado) — no dos runs independientes (uno de plan, descartado, y
  otro de apply con un plan distinto).

## 3. Verificar que un plan obsoleto se rechaza, no se reemplaza en silencio (FR-010)

En `dev` únicamente (nunca en `staging`/`production` para esta prueba):

1. Disparar el pipeline de `dev` (deja el job `apply` pendiente de la aprobación de
   `manual-review`, forzando manualmente `requires_review=true` con un cambio destructivo de prueba,
   o pausando el job con un `workflow_dispatch` manual si el repositorio lo permite).
2. Mientras ese run está pendiente, aplicar cualquier otro cambio a `dev` directamente desde otra
   ejecución (p. ej. un segundo push trivial que también dispare y complete su propio
   `check` → `apply` antes de aprobar el primero).
3. Aprobar el gate `manual-review` del primer run, ya desactualizado.

**Resultado esperado**: el `apply` del primer run falla señalando que el plan ya no es válido (HCP
Terraform lo descarta por obsoleto, research.md §1) — nunca aplica un plan recalculado en su lugar.
Si el comportamiento observado es distinto (p. ej. aplica silenciosamente algo nuevo), es un hallazgo
que invalida la Decision de research.md §1 y debe tratarse como tal, no ignorarse.

## 4. Verificar que los tres entornos son independientes (FR-008)

```text
git log --oneline -1 -- environments/dev/services.tfvars
```

Hacer un cambio que solo toque `environments/dev/**` y confirmar en la pestaña Actions de GitHub:

**Resultado esperado**: solo se dispara `terraform-apply-dev.yml`. `terraform-apply-staging.yml` y
`terraform-apply-production.yml` no aparecen como runs nuevos ni como "esperando". Repetir con un
cambio exclusivo de `environments/staging/**` y confirmar lo simétrico.

Como contraprueba, hacer un cambio en `environments/main.tf` (archivo compartido del root) y
confirmar que esta vez **sí** se disparan los tres — es el comportamiento correcto (FR-002: el
archivo es compartido de verdad), no una regresión de FR-008.

## 5. Verificar que `production` sigue exigiendo su aprobación nativa, ahora con plan visible

Disparar (o esperar) un cambio que llegue a `terraform-apply-production.yml`.

**Resultado esperado**: el job `apply` de `production` queda pausado esperando la aprobación del
GitHub Environment `production` (sin cambios de configuración — FR-011), y quien aprueba puede abrir
el job `check` de ESE MISMO run y ver el plan exacto que se aplicará al aprobar — algo que hoy no es
posible (research.md §1: `production` no genera ningún plan previo antes de aplicar).

## 6. Confirmar que un entorno nuevo solo necesitaría configuración (SC-001)

Sin crear un entorno real: listar qué archivos habría que tocar para dar de alta, por ejemplo, un
cuarto entorno `qa`.

**Resultado esperado**: `environments/qa/{environment,database,services}.tfvars` (datos de
Terraform, ya exigido desde ADR 0007); un archivo `terraform-apply-qa.yml` que solo invoca
`terraform-environment.yml` con `environment: qa` y sus propios secretos
(contracts/reusable-pipeline-interface.md); y una línea nueva ("qa") en la lista de valores
válidos de dos validaciones ya existentes: `contains([...])` de `environment_name` en
`environments/variables.tf`, y `matrix.environment` en `terraform-pr.yml`/`terraform-drift.yml`
(README, "Añadir un entorno nuevo", paso 2 — sin cambios por esta fase). Esa línea es un valor de
enumeración, no lógica (Principio IV) — lo que esta historia exige que **no** aparezca en la lista
es cualquier archivo de `modules/`, cualquier otro contenido de `environments/*.tf`, o
`terraform-environment.yml` mismo.
