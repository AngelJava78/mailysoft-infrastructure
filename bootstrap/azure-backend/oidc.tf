# T007: federacion OIDC entre GitHub Actions y Microsoft Entra ID (research.md seccion 2).
# Sin credenciales de larga duracion: cada GitHub Environment obtiene un credential federado
# propio, acotado a ese entorno (subject = repo:<owner>/<repo>:environment:<entorno>).

resource "azuread_application" "github_oidc" {
  display_name = "mailysoft-infrastructure-github-oidc"
}

resource "azuread_service_principal" "github_oidc" {
  client_id = azuread_application.github_oidc.client_id
}

#
# NOTA DE DISENO: la credencial NO se acota por GitHub Environment (subject
# "repo:...:environment:<entorno>"), a proposito. Si lo estuviera, el job de *plan* de un PR
# tendria que declarar `environment: production` solo para leer el estado/Key Vault, lo que
# activaria la regla de aprobacion manual de production (T034) unicamente para generar una
# previsualizacion de lectura — rompiendo "en pull requests solo se ejecuta plan" (FR-008).
# La proteccion real de production la aporta el gate de aprobacion de GitHub Environment en
# el job de `apply` (T034/T035), no la identidad de Azure, que es la misma para los tres
# entornos (razonable: el blindaje por entorno en este diseno vive en el Railway Project
# Token, que si esta acotado por entorno a nivel de la API de Railway — research.md seccion 2).

resource "azuread_application_federated_identity_credential" "github_pull_request" {
  application_id = azuread_application.github_oidc.id
  display_name   = "github-pull-request"
  description    = "OIDC federado para los jobs de plan disparados por pull_request en ${var.github_repository}."
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_repository}:pull_request"
}

resource "azuread_application_federated_identity_credential" "github_main_branch" {
  application_id = azuread_application.github_oidc.id
  display_name   = "github-main-branch"
  description    = "OIDC federado para los jobs de apply/drift disparados tras merge a main en ${var.github_repository}."
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_repository}:ref:refs/heads/main"
}

# Rol de minimo privilegio sobre la Storage Account del estado remoto: solo lectura/escritura
# de blobs, nada de administracion de la cuenta.
resource "azurerm_role_assignment" "github_oidc_storage" {
  scope                = azurerm_storage_account.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.github_oidc.object_id
}

# Rol de minimo privilegio sobre el Key Vault: solo lectura de secretos (el pipeline nunca
# necesita crearlos ni administrarlos, solo leer la conexion de mailysoft-db).
resource "azurerm_role_assignment" "github_oidc_keyvault" {
  scope                = azurerm_key_vault.mailysoft.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azuread_service_principal.github_oidc.object_id
}
