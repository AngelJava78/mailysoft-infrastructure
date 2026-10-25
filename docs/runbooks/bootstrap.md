# Runbook: bootstrap inicial (ejecucion única)

Este procedimiento resuelve el problema del "huevo y la gallina": antes de que exista un
backend remoto de Terraform o un proyecto de Railway, algo tiene que crearlos. Los dos
directorios bajo `bootstrap/` son la única excepción documentada al Principio III (estado
remoto obligatorio): usan estado **local**, se ejecutan **una sola vez**, y después de
ejecutarse, el resto del repositorio ya no vuelve a tocarlos salvo para añadir un nuevo
entorno o rotar una credencial.

## 1. Backend de Azure (`bootstrap/azure-backend/`)

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

## 2. Proyecto de Railway (`bootstrap/railway-project/`)

Prerrequisito: un **Account Token** de Railway, de uso exclusivo para este paso (nunca se usa
en el pipeline).

```bash
cd bootstrap/railway-project
terraform init
TF_VAR_railway_account_token="<account token>" terraform plan -out=bootstrap.tfplan
TF_VAR_railway_account_token="<account token>" terraform apply bootstrap.tfplan
```

Tras el `apply`:

1. Revocar o guardar de forma segura el Account Token usado (no debe quedar activo sin
   necesidad — principio de mínimo privilegio).
2. Desde el dashboard de Railway, emitir un **Project Token** por cada Railway Environment
   (`dev`, `staging`, `production`) — estos sí son los tokens que usa el pipeline.
3. Guardar cada Project Token como secreto **de repositorio** (no de GitHub Environment) con
   nombre por entorno — ver research.md sección 2 para por qué no se usa un secreto de
   Environment aquí (rompería "PR solo ejecuta plan" al exigir aprobación de production para
   leer el secreto):

   ```bash
   gh secret set RAILWAY_TOKEN_DEV
   gh secret set RAILWAY_TOKEN_STAGING
   gh secret set RAILWAY_TOKEN_PRODUCTION
   ```

4. Copiar `project_id` y cada `environment_ids[<entorno>]` de la salida hacia
   `environments/<entorno>/environment.tfvars` (`railway_project_id`,
   `railway_environment_id`).

## Notas de verificación pendientes

El provider comunitario de Railway no pudo verificarse contra su documentación real durante
la redacción de este módulo (sin acceso a Terraform ni al registro en el entorno donde se
escribió — ver research.md sección 1 y el ADR
[0001-railway-terraform-community-provider.md](../adr/0001-railway-terraform-community-provider.md)).
Antes de ejecutar este bootstrap por primera vez: confirmar en
`registry.terraform.io/providers/terraform-community-providers/railway/latest` que los
recursos `railway_project` y `railway_environment` existen con esos nombres y atributos
exactos, y ajustar `bootstrap/railway-project/main.tf` si difieren.
