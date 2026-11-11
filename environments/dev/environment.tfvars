# Entidad "Entorno" (data-model.md). No contiene secretos: solo identificadores de recursos
# ya creados por bootstrap/railway-project (ver docs/runbooks/bootstrap.md).

environment_name = "dev"
# ADR 0005: este directorio es un root de Terraform 100% Railway; solo puede valer "railway"
# (variables.tf lo valida con un error duro). Pasar este entorno a Azure exige un root de
# Terraform separado, no cambiar este valor.
environment_provider = "railway"
# ADR 0006: proyecto de Railway dedicado a "dev" (ya no se comparte con staging/production).
# Valores pendientes de actualizar con la salida real de "terraform apply" en
# bootstrap/railway-project (project_ids.dev / environment_ids.dev) tras recrear el bootstrap.
railway_project_id     = "42d1522d-1493-4f08-a839-91f6846df4be"
railway_environment_id = "38df29a9-ae15-4f0f-86b5-56c7dcc42558"

# FR-017: region de Railway con menor latencia hacia los usuarios reales de este entorno (ya
# no hacia Azure, desde ADR 0004 — este entorno no tiene ningun recurso en Azure). Confirmado
# 2026-11-10 contra docs.railway.com/reference/deployment-regions: las 4 regiones disponibles
# hoy son us-west2, us-east4-eqdc4a, europe-west4-drams3a, asia-southeast1-eqsg3a. Para
# usuarios en Mexico, us-east4-eqdc4a (Virginia, EE.UU.) es la de menor latencia.
region_hint = "us-east4-eqdc4a"
