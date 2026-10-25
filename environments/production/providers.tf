provider "railway" {
  # RAILWAY_TOKEN se provee como variable de entorno desde el secreto de repositorio
  # RAILWAY_TOKEN_PRODUCTION (research.md seccion 2); nunca se escribe aqui ni en ningun
  # .tfvars. El GitHub Environment "production" (sin el secreto) aporta solo la regla de
  # aprobacion manual obligatoria que usa el job de apply (FR-009, T034).
}

provider "azurerm" {
  features {}
  use_oidc = true
  # ARM_CLIENT_ID / ARM_TENANT_ID / ARM_SUBSCRIPTION_ID se proveen via OIDC desde
  # azure/login@v2 en el pipeline (research.md seccion 2).
}
