# ADR 0007: `environments/` es un solo root de Terraform parametrizado por `environment_name`

**Estado**: Aceptado
**Fecha**: 2026-11-11
**Contexto**: `environments/{dev,staging,production}` (001-railway-deployment, 002-single-provider-deployment)

## Contexto

Tras ADR 0005, `environments/dev`, `environments/staging` y `environments/production` quedaron
como tres directorios con `main.tf`, `variables.tf`, `providers.tf`, `versions.tf` y
`outputs.tf` **idénticos** entre sí (ninguna diferencia real de código, solo de valores en sus
`*.tfvars` y del nombre fijo de workspace en `backend.tf`). Esto es código duplicado sin
necesidad: cualquier cambio a `main.tf` (por ejemplo) hay que aplicarlo tres veces y mantenerlo
sincronizado a mano.

El motivo histórico de usar tres directorios en vez de un solo root parametrizado por una
variable `environment_name` (el patrón habitual: un root, N archivos `.tfvars`, un `environment`
que se pasa por variable) era que el bloque de backend de Terraform (`cloud { ... }` / `backend
"..." { ... }`) **no admite variables ni interpolación** — cada entorno "necesitaba" su propio
`backend.tf` con el nombre de workspace escrito literalmente. Pero Terraform sí soporta dejar
ese bloque **parcial** y completarlo en otro momento, lo cual permite "un solo código, N
entornos por variable" incluso con un backend que no admite interpolación. Para un backend
clásico (`backend "..." {}`) eso se hace con `-backend-config=<archivo>`; para el bloque
`cloud` (HCP Terraform, este repo) **ese flag no aplica** — confirmado 2026-11-11 contra un
`init` real: *"-backend-config=... no es aplicable a configuraciones basadas en HCP
Terraform"*. El bloque `cloud` usa su propio mecanismo: las variables de entorno
`TF_CLOUD_ORGANIZATION` y `TF_WORKSPACE`, que además hacen falta en **todo** comando de
Terraform (`init`, `plan`, `apply`) contra un bloque `cloud {}` vacío, no solo en `init`
(confirmado también contra un `plan` real: sin ellas, falla con *"Missing workspace mapping
strategy"*).

## Decisión

`environments/` pasa a ser un **solo root de Terraform**, con `main.tf`, `variables.tf`,
`providers.tf`, `versions.tf`, `outputs.tf` y `backend.tf` (bloque `cloud {}` vacío) en la raíz
de `environments/`.

Cada entorno (`dev`, `staging`, `production`) pasa a ser una **subcarpeta de solo datos**, sin
ningún archivo `.tf`:

```text
environments/
  main.tf, variables.tf, providers.tf, versions.tf, outputs.tf, backend.tf   # compartidos
  dev/
    environment.tfvars, database.tfvars, services.tfvars
  staging/        (misma estructura de datos)
  production/     (misma estructura de datos)
```

El workspace de HCP Terraform de cada entorno se completa con `TF_CLOUD_ORGANIZATION` y
`TF_WORKSPACE` (no con un archivo, ver Contexto arriba) — `mailysoft-<entorno>` siempre se
puede derivar directamente del nombre de la subcarpeta, así que no hace falta guardarlo en
ningún archivo adicional. Uso, desde `environments/`:

```bash
$env:TF_CLOUD_ORGANIZATION = "angel-java"
$env:TF_WORKSPACE           = "mailysoft-dev"   # o mailysoft-staging / mailysoft-production
terraform init
terraform plan -var-file=dev/environment.tfvars -var-file=dev/database.tfvars -var-file=dev/services.tfvars
```

Para cambiar de entorno en el mismo checkout local, basta con cambiar `$env:TF_WORKSPACE` y
volver a correr `terraform init` (sin `-reconfigure`: ese flag tampoco aplica al bloque
`cloud`, confirmado contra un init real — *"When using HCP Terraform, initialization
automatically activates any new Cloud configuration settings"*).

## Alternativas consideradas

- **Mantener las tres carpetas duplicadas**: es lo que había tras ADR 0005; descartada por
  mantenimiento innecesario (todo cambio a la lógica se escribe y revisa tres veces) sin ningún
  beneficio técnico real — el backend sí se podía parametrizar, solo no se había hecho.
- **Terraform Workspaces nativos (`terraform workspace select dev/staging/production`) en vez de
  tres workspaces de HCP Terraform distintos**: cambiaría también cómo se gestiona el estado
  remoto (un único workspace de HCP Terraform con "sub-estados" por `terraform.workspace`, en
  vez de tres workspaces independientes ya creados y documentados en ADR 0004). Rechazada por no
  aportar nada sobre lo ya decidido en ADR 0004 y por ser un cambio innecesario al backend de
  estado, cuando el problema real era solo la duplicación de código.

## Consecuencias

- Un cambio a la lógica de despliegue (`main.tf`, `variables.tf`, etc.) se escribe y revisa
  **una sola vez**, no tres.
- Usar el root localmente para un entorno distinto al último usado requiere cambiar
  `$env:TF_WORKSPACE` (y `$env:TF_CLOUD_ORGANIZATION` si no sigue puesta) y volver a
  `terraform init` (antes bastaba con `cd environments/<entorno>`). Documentado en
  `environments/backend.tf` y en `docs/runbooks/bootstrap.md`.
- Los tres workflows de CI (`terraform-pr.yml`, `terraform-apply.yml` vía sus dos acciones
  compuestas, `terraform-drift.yml`) corren `init`/`plan`/`apply` con `working-directory:
  environments`, `TF_CLOUD_ORGANIZATION`/`TF_WORKSPACE=mailysoft-<entorno>` como variables de
  entorno, y `-var-file="<entorno>/*.tfvars"`, en vez de `working-directory:
  environments/<entorno>`. `validate`/`tflint`/`checkov`
  (`terraform-pr.yml`) pasan a correr **una sola vez** sobre el root compartido, no por entorno
  en la matriz — ya no tiene sentido lintear/escanear el mismo código tres veces.
- "Añadir un entorno nuevo" (README) deja de significar "copiar `main.tf`/`variables.tf`/etc.";
  pasa a ser crear una subcarpeta con sus tres `.tfvars` y su `backend.hcl` únicamente.
- El lockfile de providers (`.terraform.lock.hcl`) pasa a vivir una sola vez en
  `environments/.terraform.lock.hcl` (antes uno por entorno, idénticos).
