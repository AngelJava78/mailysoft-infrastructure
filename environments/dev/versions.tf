# Confirmar version exacta en releases.hashicorp.com / registry.terraform.io antes del
# primer `terraform init` (research.md Fase 001-railway-deployment, seccion 7 y seccion 1).
terraform {
  required_version = "~> 1.15.0"

  required_providers {
    railway = {
      source  = "terraform-community-providers/railway"
      version = "0.6.2"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.15.0"
    }
  }
}
