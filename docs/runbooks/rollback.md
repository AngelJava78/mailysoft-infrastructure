# Runbook: volver a la última infraestructura estable (FR-013)

Este repositorio no tiene una función de "deshacer" separada: el rollback consiste en volver
a aplicar la última configuración versionada que se sabe estable, a través del mismo flujo
normal de plan → revisión → apply (research.md sección 9). Nunca se edita el estado de
Terraform a mano ni se aplica nada fuera del pipeline.

## Procedimiento

1. **Identificar el último commit estable** sobre `main` (por ejemplo, el commit inmediato
   anterior al cambio problemático, o un tag si el equipo los usa).

2. **Revertir el cambio problemático**, preferiblemente con `git revert` (preserva el
   historial, evita reescribir `main`):

   ```bash
   git revert <commit-problematico> --no-edit
   git push origin main
   ```

   Si el cambio problemático abarca varios commits, usar
   `git revert <mas-antiguo>^..<mas-reciente>`.

3. **Dejar que el pipeline haga el resto**: el push a `main` dispara, para cada entorno cuya
   configuración cambió, su propio `terraform-apply-<entorno>.yml` (ADR 0009) — que a su vez
   invoca `terraform-environment.yml` — igual que cualquier otro cambio:
   - `dev` y `staging` aplican automáticamente.
   - `production` se detiene en el gate de aprobación manual (FR-009) — un responsable
     técnico debe abrir el job `check` de ese mismo run (ahora siempre genera un plan previo,
     ADR 0008) para revisar la previsualización (que ahora muestra que se está volviendo al
     estado anterior) y aprobarla explícitamente, igual que cualquier otro cambio.

4. **Si el revert no es posible** (por ejemplo, porque el cambio problemático ya fue
   seguido de otros cambios incompatibles): crear un nuevo commit que reescriba
   manualmente los `.tfvars` del entorno afectado al estado conocido como estable, y
   seguir el mismo flujo plan → revisión → apply.

## Qué NO hacer

- No ejecutar `terraform apply` desde una máquina local contra `staging`/`production`
  (Principio V).
- No editar el archivo de estado remoto directamente.
- No usar `terraform destroy` como mecanismo de rollback: el objetivo es volver a un
  **estado anterior conocido**, no eliminar recursos.
- No tocar la consola de Railway ni la de Azure manualmente para "arreglarlo rápido": si se
  hace, el siguiente ciclo de [detección de drift](../../.github/workflows/terraform-drift.yml)
  lo reportará como una diferencia no planeada (FR-015), y habrá que revertirlo igual por
  este mismo procedimiento.

## Caso especial: `bootstrap/`

Los directorios bajo `bootstrap/` (ver [bootstrap.md](./bootstrap.md)) usan estado local y
se ejecutan una sola vez. Si algo falla ahí, no hay "rollback" vía pipeline: se corrige
manualmente el `.tf` correspondiente y se vuelve a ejecutar `terraform apply` localmente,
con la misma precaución de revisar el plan antes de aplicar.
