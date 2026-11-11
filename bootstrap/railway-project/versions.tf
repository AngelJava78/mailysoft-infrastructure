# Excepcion documentada al Principio III: estado local de un solo uso para resolver el
# problema del huevo y la gallina (no hay backend remoto de Railway que usar aqui, y crear
# el proyecto/entornos es, en si mismo, el paso que luego permite emitir los Project Tokens
# que usara el pipeline). Ver docs/runbooks/bootstrap.md y research.md secciones 1 y 3.
#
# ADVERTENCIA (research.md seccion 1): terraform-community-providers/railway es un provider
# NO oficial. Verificar la version exacta y el esquema real de recursos en
# registry.terraform.io/providers/terraform-community-providers/railway/latest antes del
# primer apply; no se pudo confirmar contra el registro en el momento de escribir este modulo.
# required_version confirmado 2026-11-09 contra la version real instalada (Terraform v1.17.1).
terraform {
  required_version = "~> 1.17.0"

  required_providers {
    railway = {
      source  = "terraform-community-providers/railway"
      version = "0.6.2"
    }
    # Provider oficial de HashiCorp (hashicorp/time): unicamente para time_sleep, que impone la
    # espera entre la creacion de cada railway_project exigida por el limite de tasa de Railway
    # (ver main.tf). No gestiona ningun recurso de Railway.
    time = {
      source  = "hashicorp/time"
      version = "~> 0.11"
    }
  }
}
