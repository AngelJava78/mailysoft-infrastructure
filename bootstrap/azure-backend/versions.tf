# Este directorio es una EXCEPCION documentada al Principio III (estado remoto obligatorio):
# usa estado LOCAL de un solo uso porque su proposito es crear el propio backend remoto que
# el resto del repositorio usara. Ver docs/runbooks/bootstrap.md y research.md Fase
# 001-railway-deployment, seccion 6.
#
# NOTA: confirmar la version exacta disponible en releases.hashicorp.com / registry.terraform.io
# antes de ejecutar `terraform init` por primera vez (research.md seccion 7).
terraform {
  required_version = "~> 1.15.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.15.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "3.1.0"
    }
  }
}
