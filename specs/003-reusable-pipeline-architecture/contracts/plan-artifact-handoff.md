# Contrato: Traspaso del artefacto de plan entre `check` y `apply`

**Spec**: [spec.md](../spec.md) | **Research**: [research.md](../research.md) §1

Este contrato describe cómo el job `check` de `terraform-environment.yml` entrega su plan al job
`apply` de la misma invocación, de forma que lo revisado y lo aplicado sean siempre el mismo
artefacto (FR-009/FR-010).

## Productor: job `check`

1. Ejecuta `terraform plan -out=<environment>.tfplan` (ya lo hace hoy `terraform-check-provider-mix`,
   solo cambia el nombre del archivo de `check.tfplan` genérico a uno calificado por entorno).
2. Publica `<environment>.tfplan` como artefacto del run de GitHub Actions
   (`actions/upload-artifact`), con nombre `tfplan-<environment>` y retención mínima necesaria para
   que el job `apply` de la misma invocación pueda descargarlo (un solo run; no necesita persistir
   más allá de él).
3. Sigue exponiendo `requires_review` como hoy (sin cambios).

## Consumidor: job `apply`

1. Descarga el artefacto `tfplan-<environment>` (`actions/download-artifact`) publicado por el job
   `check` de esta misma invocación — nunca de otra invocación, otro run, ni otro entorno.
2. Ejecuta `terraform apply <environment>.tfplan` (nunca `terraform apply -auto-approve -var-file=...`
   — esa forma recalcula un plan nuevo, exactamente lo que este contrato prohíbe).
3. Si HCP Terraform rechaza el plan por estar obsoleto (research.md §1 — el estado real del entorno
   cambió después de que `check` generó el plan), el job `apply` MUST fallar de forma visible,
   señalando que se requiere una ejecución nueva; MUST NOT reintentar con un plan recalculado dentro
   de la misma invocación.

## Precondición operativa (a reconfirmar, no a asumir)

El workspace de HCP Terraform de cada entorno (`mailysoft-dev`, `mailysoft-staging`,
`mailysoft-production`) MUST estar en *Execution Mode* "Local" (Workspace → Settings → General, en
HCP Terraform). Esto ya está documentado como parte de la decisión original de
[ADR 0004](../../../docs/adr/0004-backend-estado-desacoplado-de-proveedor.md) (2026-11-09) — no es
una condición nueva de esta fase — pero, al ser la base de todo este contrato, MUST reconfirmarse
visualmente antes de depender de él en `production` (quickstart.md §1), por si cambió desde
entonces. El flujo de "Remote Saved Plans" entre máquinas distintas que da soporte a este contrato
está confirmado contra la documentación oficial para el modo "Local" (research.md §1). La tarea de
implementación que active este contrato para `production` MUST haberlo validado primero en `dev`
(quickstart.md).

## Qué pasa si el artefacto no existe

Si el job `apply` se ejecuta sin que exista el artefacto `tfplan-<environment>` de su propio run
(p. ej. porque el job `check` falló o se saltó), `apply` MUST NOT continuar con un plan recalculado
como alternativa silenciosa — MUST fallar, ya que aplicar sin el plan que se evaluó en `check`
(incluida la evaluación de FR-010/FR-014) es precisamente el escenario que este contrato existe para
impedir.
