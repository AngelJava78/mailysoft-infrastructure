# ADR 0005: este root de Terraform es 100% Railway. NUNCA declara el provider azurerm ni
# referencia (ni siquiera con count = 0) ningun modulo que lo requiera - confirmado
# 2026-11-10 contra un plan real que la sola presencia estatica de un modulo que requiere
# azurerm en el arbol de configuracion obliga a Terraform a configurarlo de verdad (intenta
# autenticarse contra Azure sin importar el count ni las credenciales que se le den). Elegir
# Azure para un entorno exige un root de Terraform distinto (ver ADR 0005 y
# docs/runbooks/bootstrap.md), no un valor de variable en este mismo archivo.
provider "railway" {
  # RAILWAY_TOKEN se provee como variable de entorno desde el secreto de repositorio con
  # nombre por entorno (RAILWAY_TOKEN_DEV/STAGING/PRODUCTION, research.md seccion 2); nunca se
  # escribe aqui ni en ningun .tfvars.
}
