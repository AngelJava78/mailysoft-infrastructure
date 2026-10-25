# Excepcion documentada al Principio III: estado local de un solo uso para resolver el
# problema del huevo y la gallina (no hay backend remoto de Railway que usar aqui, y crear
# el proyecto/entornos es, en si mismo, el paso que luego permite emitir los Project Tokens
# que usara el pipeline). Ver docs/runbooks/bootstrap.md y research.md secciones 1 y 3.
#
# ADVERTENCIA (research.md seccion 1): terraform-community-providers/railway es un provider
# NO oficial. Verificar la version exacta y el esquema real de recursos en
# registry.terraform.io/providers/terraform-community-providers/railway/latest antes del
# primer apply; no se pudo confirmar contra el registro en el momento de escribir este modulo.
terraform {
  required_version = "~> 1.15.0"

  required_providers {
    railway = {
      source  = "terraform-community-providers/railway"
      version = "0.6.2"
    }
  }
}
