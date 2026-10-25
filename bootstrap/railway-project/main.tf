# T009: proyecto Railway unico + un Railway Environment nativo por entorno de la plataforma
# (research.md seccion 3). Los servicios en si se crean despues, por entorno, desde
# environments/<entorno>/main.tf usando modules/service/railway.

resource "railway_project" "mailysoft" {
  name = var.project_name
}

# NOTA (research.md seccion 1): no se pudo confirmar contra el registro si el recurso para
# un Railway Environment adicional se llama "railway_environment" o si requiere otro nombre
# de atributo distinto a "project_id"/"name". Verificar contra la documentacion real del
# provider antes del primer apply; de no existir este recurso, los entornos adicionales
# (staging, production) deberan crearse manualmente por unica vez desde el dashboard de
# Railway y su id registrarse igualmente en environment.tfvars.
resource "railway_environment" "this" {
  for_each = toset(var.environment_names)

  project_id = railway_project.mailysoft.id
  name       = each.value
}
