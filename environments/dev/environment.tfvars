# Entidad "Entorno" (data-model.md). No contiene secretos: solo identificadores de recursos
# ya creados por bootstrap/railway-project (ver docs/runbooks/bootstrap.md).

environment_name       = "dev"
railway_project_id     = "<project_id de la salida de bootstrap/railway-project>"
railway_environment_id = "<environment_ids.dev de la salida de bootstrap/railway-project>"

# FR-017: region de Railway mas cercana a la region de Azure donde vive mailysoft-db, de
# entre las que soportan los servicios requeridos. Confirmar valor exacto contra
# docs.railway.com/reference/deployment-regions y la region real de mailysoft-db antes de
# fijarlo (research.md, aclaracion de spec.md).
region_hint = "<region de Railway mas cercana a Azure, ej. us-west2>"
