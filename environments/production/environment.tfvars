environment_name       = "production"
# FR-001 (002-single-provider-deployment): "railway" o "azure". Cambiar este valor en
# production reemplaza todos sus servicios y su base de datos (FR-015): requiere la misma
# aprobacion manual explicita que cualquier cambio destructivo.
environment_provider   = "railway"
railway_project_id     = "<project_id de la salida de bootstrap/railway-project>"
railway_environment_id = "<environment_ids.production de la salida de bootstrap/railway-project>"
region_hint            = "<region de Railway mas cercana a Azure, ej. us-west2>"
azure_location          = "<region de Azure, ej. eastus; solo si environment_provider = \"azure\">"
