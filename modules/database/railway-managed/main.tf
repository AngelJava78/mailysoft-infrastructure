# research.md de 002-single-provider-deployment, seccion 3: cuando un entorno elige Railway
# y todavia no tiene base de datos propia ahi, se aprovisiona un railway_service mas (el
# mismo tipo de recurso que ya usa modules/service/railway) desde la imagen oficial de
# Postgres con SSL de Railway, con un volumen persistente adjunto. A diferencia de
# modules/database/azure-existing, este modulo SI declara resources de escritura: crea su
# propia base de datos, nunca la que ya existe en Azure (FR-012; contracts/database-module-interface.md).
#
# ADVERTENCIA (research.md §3): no se confirmo contra registry.terraform.io que
# terraform-community-providers/railway exponga un recurso de volumen persistente con el
# nombre y los atributos exactos usados aqui (railway_volume), ni que railway_service acepte
# desplegarse desde una imagen de contenedor (source_image) en vez de un repositorio
# (source_repo, unico atributo usado hasta ahora en modules/service/railway). La comunidad de
# Railway ha reportado al menos un caso de error 504 al crear un volumen con este provider
# (station.railway.com). CONFIRMAR ambos recursos/atributos antes del primer `apply` real.

resource "random_password" "postgres" {
  length  = 32
  special = false # algunos caracteres especiales rompen cadenas de conexion de Postgres sin escapar; se evita el problema en vez de resolverlo
}

resource "railway_service" "postgres" {
  project_id     = var.railway_project_id
  environment_id = var.railway_environment_id
  name           = "mailysoft-db-${var.environment_name}"
  region         = var.region

  source_image = var.postgres_image # ver advertencia de este archivo: atributo sin confirmar contra el provider real
}

resource "railway_volume" "postgres_data" {
  project_id     = var.railway_project_id
  environment_id = var.railway_environment_id
  service_id     = railway_service.postgres.id
  mount_path     = "/var/lib/postgresql/data"
  size_gb        = var.volume_size_gb
}

locals {
  postgres_env_vars = {
    POSTGRES_DB   = var.database_name
    POSTGRES_USER = "mailysoft"
  }
}

resource "railway_variable" "env" {
  for_each = local.postgres_env_vars

  project_id     = var.railway_project_id
  environment_id = var.railway_environment_id
  service_id     = railway_service.postgres.id
  name           = each.key
  value          = each.value
}

resource "railway_variable" "password" {
  project_id     = var.railway_project_id
  environment_id = var.railway_environment_id
  service_id     = railway_service.postgres.id
  name           = "POSTGRES_PASSWORD"
  value          = random_password.postgres.result
  sensitive      = true
}
