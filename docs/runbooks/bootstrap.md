# Runbook: bootstrap inicial (ejecucion única)

Este procedimiento resuelve el problema del "huevo y la gallina": antes de que exista un
backend remoto de Terraform o un proyecto de Railway, algo tiene que crearlos. Los dos
directorios bajo `bootstrap/` son la única excepción documentada al Principio III (estado
remoto obligatorio): usan estado **local**, se ejecutan **una sola vez**, y después de
ejecutarse, el resto del repositorio ya no vuelve a tocarlos salvo para añadir un nuevo
entorno o rotar una credencial.

## Opcional: variables en un archivo de PowerShell

En vez de repetir `-var="..."` en cada comando, copiar
[`bootstrap/local.settings.ps1.example`](../../bootstrap/local.settings.ps1.example) a
`bootstrap/local.settings.ps1` (ya en `.gitignore`: nunca se commitea), rellenar los valores
reales, y cargarlos en la sesión actual antes de los pasos 1 y 2 de abajo:

```powershell
Copy-Item bootstrap/local.settings.ps1.example bootstrap/local.settings.ps1
notepad bootstrap/local.settings.ps1   # rellenar los valores reales
. .\bootstrap\local.settings.ps1       # dot-source: carga las variables TF_VAR_* en esta sesion
```

Con eso, `terraform plan`/`apply` en ambos bootstraps ya no necesitan ningún `-var="..."`
(Terraform lee automáticamente cualquier `TF_VAR_<nombre>` del entorno). Cerrar la sesión de
PowerShell al terminar (o `Remove-Item Env:TF_VAR_*`) para no dejar el Account Token ni las
credenciales de Azure cargados más tiempo del necesario.

## 1. Backend de estado de Terraform (HCP Terraform)

**ADR [0004](../adr/0004-backend-estado-desacoplado-de-proveedor.md)**: el backend de estado
ya no es siempre Azure — sigue a `environment_provider` de cada entorno. Con
`environment_provider = "railway"` (los tres entornos hoy), el backend es HCP Terraform
(*free tier*), sin ninguna cuenta/tenant de Azure de por medio. No hace falta ningún código de
Terraform para esto, solo configuración en app.terraform.io:

1. Crear una cuenta gratuita en [app.terraform.io](https://app.terraform.io) y una
   **organización** (ADR 0007: `environments/` es un solo root compartido; `backend.tf` en su
   raíz deja el bloque `cloud {}` vacío a propósito — el nombre de la organización se provee
   con la variable de entorno `TF_CLOUD_ORGANIZATION`, no en ningún archivo `.tf`).
2. Crear un **workspace** por entorno: `mailysoft-dev`, `mailysoft-staging`,
   `mailysoft-production`. En cada uno, ir a **Settings → General → Execution Mode** y
   ponerlo en **Local** (crítico: con el modo remoto por defecto, el pipeline no podría seguir
   parseando `plan.json` localmente para FR-010/FR-014 — HCP Terraform aquí solo almacena y
   bloquea el estado, el `plan`/`apply` sigue corriendo en CI, igual que antes con `azurerm`).
3. Generar un **token de API** (perfil de usuario o de equipo → Tokens) y guardarlo como
   secreto de repositorio:

   ```bash
   gh secret set TFC_API_TOKEN
   ```

4. Desde `environments/` (no desde `environments/dev/`, ADR 0007), con las dos variables que
   le indican a Terraform qué workspace de HCP Terraform usar (confirmado 2026-11-11 contra un
   init real: el bloque `cloud {}` no admite `-backend-config` como un backend clásico, usa
   estas variables en su lugar — y hacen falta en todo comando, no solo en `init`):

   ```powershell
   cd environments
   $env:TF_CLOUD_ORGANIZATION = "<tu organizacion>"
   $env:TF_WORKSPACE           = "mailysoft-dev"
   terraform init
   ```

   Para trabajar luego contra otro entorno en el mismo checkout local, basta con cambiar
   `$env:TF_WORKSPACE` (p. ej. `"mailysoft-staging"`) y volver a `terraform init` — sin
   `-reconfigure`, que tampoco aplica aquí.

   Sin credenciales de Azure de ningún tipo.

## Opcional: backend de Azure (`bootstrap/azure-backend/`)

Solo hace falta si algún entorno pasa a `environment_provider = "azure"` (ahí Azure ya es
parte necesaria de ese entorno de todas formas — ver ADR 0004). Para un entorno en Railway,
**saltar esta sección por completo**.

Prerrequisitos: sesión de `az login` con permisos para crear recursos en la subscripción, y
el resource group donde ya vive `mailysoft-db` (o uno dedicado).

```bash
cd bootstrap/azure-backend
terraform init
terraform plan -out=bootstrap.tfplan \
  -var="azure_subscription_id=<subscription id>" \
  -var="azure_tenant_id=<tenant id>" \
  -var="resource_group_name=<resource group>" \
  -var="location=<region>" \
  -var="storage_account_name=<nombre unico, 3-24 caracteres>" \
  -var="key_vault_name=<nombre del key vault>" \
  -var="github_repository=AngelJava78/mailysoft-infrastructure"
terraform apply bootstrap.tfplan
```

Tras el `apply`:

1. Fijar el valor real de la contraseña de conexión de `mailysoft-db` (el recurso Terraform
   solo reserva el nombre del secreto, nunca su valor real — FR-011):

   ```bash
   az keyvault secret set \
     --vault-name <key_vault_name de la salida> \
     --name mailysoft-db-connection \
     --value "<cadena de conexión real, nunca commiteada>"
   ```

2. Copiar los outputs (`storage_account_name`, `key_vault_id`, `github_oidc_client_id`,
   `azure_tenant_id`, `azure_subscription_id`) hacia:
   - `environments/<entorno>/backend.tf` (nombre de la storage account + contenedor)
   - `environments/<entorno>/database.tfvars` (`key_vault_id`)
   - Los secretos **de repositorio** `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`,
     `AZURE_SUBSCRIPTION_ID` (no de GitHub Environment — la federación OIDC está acotada por
     evento `pull_request` / rama `main`, no por entorno; ver research.md sección 2 y
     `bootstrap/azure-backend/oidc.tf`), para que `azure/login@v2` use OIDC sin credenciales
     de larga duración, igual en los tres entornos.

## 2. Proyectos de Railway (`bootstrap/railway-project/`)

**ADR [0006](../adr/0006-un-proyecto-railway-por-entorno.md)**: un proyecto de Railway **por
entorno** (`maily-soft-dev`, `maily-soft-staging`, `maily-soft-production`), no un único
proyecto con tres Environments — confirmado contra un apply real que un "Environment" dentro de
un mismo proyecto no aísla servicios con nombre propio (el nombre debe ser único a nivel de
proyecto, no de entorno).

Prerrequisito: un **Account Token** de Railway, de uso exclusivo para este paso (nunca se usa
en el pipeline).

Por omisión solo se crea el proyecto de `dev` (`var.environments_to_create = ["dev"]`) — para
crear también `staging` y/o `production` en el mismo apply o en uno posterior, pasar la lista
completa de los que deban existir (incluyendo los ya creados, para no destruirlos):

```bash
cd bootstrap/railway-project
terraform init
TF_VAR_railway_account_token="<account token>" terraform apply
# o, cuando toque sumar staging (semanas después, por ejemplo):
TF_VAR_railway_account_token="<account token>" terraform apply -var='environments_to_create=["dev","staging"]'
```

Tras el `apply`:

1. Revocar o guardar de forma segura el Account Token usado (no debe quedar activo sin
   necesidad — principio de mínimo privilegio).
2. Desde el dashboard de Railway, emitir un **Project Token** por cada proyecto
   (`maily-soft-dev`, `maily-soft-staging`, `maily-soft-production`) — estos sí son los tokens
   que usa el pipeline día a día (no sirven para crear servicios nuevos, solo para administrar
   los que ya existen — ver nota de `terraform-provider-railway` más abajo).
3. Guardar cada Project Token como secreto **de repositorio** (no de GitHub Environment) con
   nombre por entorno — ver research.md sección 2 para por qué no se usa un secreto de
   Environment aquí (rompería "PR solo ejecuta plan" al exigir aprobación de production para
   leer el secreto):

   ```bash
   gh secret set RAILWAY_TOKEN_DEV
   gh secret set RAILWAY_TOKEN_STAGING
   gh secret set RAILWAY_TOKEN_PRODUCTION
   ```

4. Copiar `project_ids[<entorno>]` y `environment_ids[<entorno>]` de la salida hacia el
   `environments/<entorno>/environment.tfvars` correspondiente (`railway_project_id`,
   `railway_environment_id`) — cada entorno tiene ahora su **propio** proyecto, ya no comparten
   el mismo `railway_project_id`.

## Notas de verificación pendientes

**`railway_project`/`railway_environment` (este bootstrap): confirmado el 2026-11-09** contra
`docs/resources/{project,environment}.md` del repositorio del provider
(`terraform-community-providers/terraform-provider-railway`, rama `main`) — los nombres de
recurso y atributos de `bootstrap/railway-project/main.tf` son correctos tal como están
(`railway_project.name`; `railway_environment.project_id`/`.name`).

**Confirmado contra un `apply` real (2026-11-09): la salvedad de `workspace_id` se da en la
práctica.** `bootstrap/railway-project` ya declara `workspace_id` como variable (nullable, por
si algún Account Token tiene un solo workspace y de verdad no lo necesita). Obtener el id del
workspace desde el dashboard de Railway — command palette (Ctrl/Cmd+K) sobre el workspace
activo — y añadirlo a `bootstrap/local.settings.ps1` junto al resto de las variables:

```powershell
$env:TF_VAR_workspace_id = "<workspace id de Railway>"
```

El resto del provider (`modules/service/railway`, `modules/network-domain/railway`, y el
atributo `source_image`/recurso de volumen de `modules/database/railway-managed`) **sigue
sin verificar** contra el registro — ver research.md sección 1 y el ADR
[0001-railway-terraform-community-provider.md](../adr/0001-railway-terraform-community-provider.md)
y [0003-railway-postgres-sin-verificar.md](../adr/0003-railway-postgres-sin-verificar.md).
Confirmar esos antes del primer `apply` real de un entorno completo.

**Un proyecto de Railway por entorno, confirmado necesario el 2026-11-11 (ADR
[0006](../adr/0006-un-proyecto-railway-por-entorno.md))**: contra un `apply` real de
`environments/dev`, un "Environment" dentro de un único proyecto de Railway resultó NO aislar
servicios con nombre propio — el nombre debe ser único a nivel de todo el proyecto, no de
entorno, y el provider usado ni siquiera envía `environmentId` al crear un `railway_service`.
`bootstrap/railway-project` crea ahora tres proyectos independientes
(`maily-soft-dev`/`-staging`/`-production`), cada uno con el ambiente por defecto que Railway le
asigna automáticamente (renombrado solo por claridad en el dashboard). El límite de tasa de
Railway también aplica a la creación de proyectos, confirmado contra un apply real
(2026-11-11): `"You are creating projects too quickly. This workspace allows 1 project per 30
seconds."` — por eso `main.tf` sigue usando `time_sleep` (40s de margen) entre la creación de
cada proyecto, igual que antes entre `railway_environment.dev` y `.staging`.
