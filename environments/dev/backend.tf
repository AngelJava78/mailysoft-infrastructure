# Backend remoto con bloqueo (lease nativo de Blob) y cifrado en reposo, separado por
# entorno (Principio III, research.md seccion 6). Los valores exactos de resource_group_name
# y storage_account_name son la salida de bootstrap/azure-backend (ver
# docs/runbooks/bootstrap.md) — completarlos tras ejecutar ese bootstrap una sola vez.
terraform {
  backend "azurerm" {
    resource_group_name = "<resource_group_name de la salida de bootstrap/azure-backend>"
    storage_account_name = "<storage_account_name de la salida de bootstrap/azure-backend>"
    container_name       = "tfstate-dev"
    key                   = "railway-deployment.tfstate"
    use_oidc              = true
  }
}
