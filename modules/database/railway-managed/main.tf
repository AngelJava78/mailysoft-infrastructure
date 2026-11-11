# research.md de 002-single-provider-deployment, seccion 3: cuando un entorno elige Railway
# y todavia no tiene base de datos propia ahi, se aprovisiona un railway_service mas (el
# mismo tipo de recurso que ya usa modules/service/railway) desde la imagen oficial de
# Postgres con SSL de Railway, con un volumen persistente adjunto. A diferencia de
# modules/database/azure-existing, este modulo SI declara resources de escritura: crea su
# propia base de datos, nunca la que ya existe en Azure (FR-012; contracts/database-module-interface.md).
#
# Confirmado 2026-11-10 contra un `terraform plan` real: "railway_volume" NO existe como
# recurso en terraform-community-providers/railway (ninguna version) — el volumen persistente
# es un bloque anidado "volume" DENTRO del propio "railway_service" (docs/resources/service.md
# del repositorio del provider), no un recurso aparte. Igual que en modules/service/railway:
# "railway_service" no tiene "environment_id" (se crea a nivel de proyecto), y la region es
# "regions" (lista de objetos), no "region" escalar.
#
# SIN CONFIRMAR todavia: los atributos exactos dentro del bloque "volume" mas alla de
# "mount_path" (p. ej. si el tamano del volumen es configurable via Terraform o se administra
# aparte) — por eso var.volume_size_gb, abajo, no se conecta a nada todavia. Ajustar segun la
# salida real del siguiente `terraform plan`/`apply`.

resource "random_password" "postgres" {
  length  = 32
  special = false # algunos caracteres especiales rompen cadenas de conexion de Postgres sin escapar; se evita el problema en vez de resolverlo
}

resource "railway_service" "postgres" {
  project_id = var.railway_project_id
  name       = "mailysoft-db-${var.environment_name}"

  source_image = var.postgres_image

  # var.region NO se conecta a "regions" todavia: mismo bug confirmado del provider que
  # modules/service/railway/main.tf (ver su comentario) - "Value Conversion Error" tanto con
  # una lista de un elemento como con una lista vacia.

  # Confirmado 2026-11-10 contra un plan real: el bloque "volume" exige tambien "name",
  # ademas de "mount_path".
  volume = {
    name       = "postgres-data"
    mount_path = "/var/lib/postgresql/data"
  }
}

locals {
  postgres_env_vars = {
    POSTGRES_DB   = var.database_name
    POSTGRES_USER = "mailysoft"
  }
}

# Confirmado 2026-11-10 contra un plan real: "railway_variable" no tiene "project_id" (de
# solo lectura, se infiere de service_id) ni "sensitive" (el atributo "value" ya viene
# marcado Sensitive en el propio esquema del provider, redactado automaticamente en
# plan/state sin configuracion adicional - FR-011 queda cubierto igual).
resource "railway_variable" "env" {
  for_each = local.postgres_env_vars

  environment_id = var.railway_environment_id
  service_id     = railway_service.postgres.id
  name           = each.key
  value          = each.value
}

resource "railway_variable" "password" {
  environment_id = var.railway_environment_id
  service_id     = railway_service.postgres.id
  name           = "POSTGRES_PASSWORD"
  value          = random_password.postgres.result
}
