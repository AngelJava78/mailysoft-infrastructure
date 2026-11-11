# Backend remoto con bloqueo y versionado, sin requerir ninguna cuenta/tenant de Azure
# (ADR 0004: estado remoto desacoplado de environment_provider). Un solo root compartido por
# los tres entornos (ADR 0007): el bloque "cloud" se deja vacio a proposito y se completa con
# variables de entorno en vez de -backend-config (confirmado 2026-11-11 contra un init real:
# "-backend-config=... no es aplicable a configuraciones basadas en HCP Terraform" — ese flag
# es solo para backends clasicos; el bloque "cloud" usa su propio mecanismo de variables):
#
#   $env:TF_CLOUD_ORGANIZATION = "angel-java"
#   $env:TF_WORKSPACE           = "mailysoft-dev"   # o mailysoft-staging / mailysoft-production
#   terraform init
#
# Si ya se habia inicializado contra otro entorno en el mismo directorio local, agregar
# "-reconfigure" para cambiar de workspace sin arrastrar el anterior.
#
# Crear una vez, manualmente, en app.terraform.io (docs/runbooks/bootstrap.md): una
# organizacion, y dentro de ella un workspace por entorno ("mailysoft-dev", "mailysoft-staging",
# "mailysoft-production") con Execution Mode = "Local" (critico: con el modo remoto por
# defecto, el pipeline dejaria de poder parsear plan.json/tfplan localmente para FR-010/FR-014).
terraform {
  cloud {}
}
