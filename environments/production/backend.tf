# Backend remoto con bloqueo y cifrado en reposo, separado por entorno (Principio III,
# research.md seccion 6). Mismo Storage Account que dev/staging, contenedor distinto.
terraform {
  backend "azurerm" {
    resource_group_name  = "<resource_group_name de la salida de bootstrap/azure-backend>"
    storage_account_name = "<storage_account_name de la salida de bootstrap/azure-backend>"
    container_name        = "tfstate-production"
    key                   = "railway-deployment.tfstate"
    use_oidc              = true
  }
}
