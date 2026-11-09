# Entidad "Entorno" (data-model.md). No contiene secretos: solo identificadores de recursos
# ya creados por bootstrap/railway-project (ver docs/runbooks/bootstrap.md).

environment_name       = "dev"
# FR-001 (002-single-provider-deployment): "railway" o "azure". Cambiar este unico valor
# mueve las dos apps, las seis APIs y la base de datos de este entorno al otro proveedor.
environment_provider   = "railway"
railway_project_id     = "<project_id de la salida de bootstrap/railway-project>"
railway_environment_id = "<environment_ids.dev de la salida de bootstrap/railway-project>"

# Solo se usan cuando environment_provider = "azure" (002-single-provider-deployment).
azure_location = "<region de Azure, ej. eastus>"

# FR-017: region de Railway mas cercana a la region de Azure donde vive mailysoft-db, de
# entre las que soportan los servicios requeridos. Confirmar valor exacto contra
# docs.railway.com/reference/deployment-regions y la region real de mailysoft-db antes de
# fijarlo (research.md, aclaracion de spec.md).
region_hint = "<region de Railway mas cercana a Azure, ej. us-west2>"
