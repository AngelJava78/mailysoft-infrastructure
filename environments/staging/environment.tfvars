environment_name       = "staging"
# FR-001 (002-single-provider-deployment): "railway" o "azure".
environment_provider   = "railway"
railway_project_id     = "<project_id de la salida de bootstrap/railway-project>"
railway_environment_id = "<environment_ids.staging de la salida de bootstrap/railway-project>"
region_hint            = "<region de Railway mas cercana a Azure, ej. us-west2>"
azure_location          = "<region de Azure, ej. eastus; solo si environment_provider = \"azure\">"
