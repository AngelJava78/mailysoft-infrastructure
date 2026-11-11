environment_name = "production"
# ADR 0005: este directorio es un root de Terraform 100% Railway; solo puede valer "railway"
# (variables.tf lo valida con un error duro). Pasar este entorno a Azure exige un root de
# Terraform separado, no cambiar este valor.
environment_provider = "railway"
# ADR 0006: proyecto de Railway dedicado a "production" (ya no se comparte con dev/staging).
# Valores pendientes de actualizar con la salida real de "terraform apply" en
# bootstrap/railway-project (project_ids.production / environment_ids.production).
railway_project_id     = "<project_ids.production de la salida del bootstrap>"
railway_environment_id = "<environment_ids.production de la salida del bootstrap>"
# FR-017: region de Railway con menor latencia hacia los usuarios reales. Mismo valor que dev
# (ver environments/dev/environment.tfvars) — usuarios en Mexico, us-east4-eqdc4a (Virginia,
# EE.UU.) es la de menor latencia de las 4 disponibles.
region_hint = "us-east4-eqdc4a"
