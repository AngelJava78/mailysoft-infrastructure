# T009 (corregido por ADR 0006): un proyecto de Railway POR ENTORNO de la plataforma, no un
# unico proyecto con tres Railway Environments nativos. Motivo (confirmado 2026-11-11 contra
# un apply real): dentro de un mismo proyecto de Railway, un "Environment" es solo una vista de
# despliegue — el objeto "service" pertenece al PROYECTO completo y su nombre debe ser unico a
# nivel de proyecto, no de entorno (confirmado tambien por el staff de Railway en su foro
# oficial, station.railway.com). Un servicio creado "para dev" terminaba visible (como
# "offline") en las pestañas staging/prod del mismo proyecto, y chocaba por nombre con
# cualquier intento de recrearlo. El provider de Terraform usado aqui tampoco envia
# "environmentId" al crear un railway_service (confirmado contra su codigo fuente), asi que hoy
# no hay forma de pedirle aislamiento por entorno dentro de un proyecto compartido. Ver ADR
# 0006 para la decision completa y las alternativas consideradas.
#
# var.environments_to_create controla cuales de los tres proyectos existen en un momento dado:
# permite crear "dev" ahora y agregar "staging"/"production" en applies posteriores, dias o
# semanas despues, sin recrear ni tocar lo que ya existe. IMPORTANTE: cada apply debe incluir
# TODOS los entornos que deban seguir existiendo, no solo el nuevo — omitir uno que ya se creo
# hace que Terraform planee destruirlo (count pasa a 0).
resource "railway_project" "dev" {
  count = contains(var.environments_to_create, "dev") ? 1 : 0

  name = "${var.project_name}-dev"
  # Confirmado 2026-11-09 contra un apply real: el Account Token usado puede acceder a mas de
  # un workspace de Railway, asi que la API exige workspace_id explicitamente (de otro modo
  # falla con "You must specify a workspaceId to create a project").
  workspace_id = var.workspace_id
  # Cosmetico unicamente: Railway nombra "production" al ambiente que crea solo con el
  # proyecto; aqui se renombra para que coincida con el entorno al que pertenece este proyecto.
  # El resto del repositorio nunca referencia este ambiente por nombre, solo por id
  # (railway_environment_id en cada environment.tfvars).
  default_environment = {
    name = "dev"
  }
}

# Confirmado 2026-11-11 contra un apply real: la API de Railway tambien limita projectCreate a
# 1 por 30 segundos por workspace ("You are creating projects too quickly"), igual que ya
# ocurria con railway_environment. Mismo mecanismo que antes: recursos explicitos (no for_each)
# con un time_sleep de 40s (margen sobre el limite real de 30s) entre cada creacion, para que un
# apply que cree mas de uno en una sola pasada no choque con ese limite.
resource "time_sleep" "before_staging" {
  count = contains(var.environments_to_create, "staging") ? 1 : 0

  depends_on      = [railway_project.dev]
  create_duration = "40s"
}

resource "railway_project" "staging" {
  count = contains(var.environments_to_create, "staging") ? 1 : 0

  name         = "${var.project_name}-staging"
  workspace_id = var.workspace_id
  default_environment = {
    name = "staging"
  }

  depends_on = [time_sleep.before_staging]
}

resource "time_sleep" "before_production" {
  count = contains(var.environments_to_create, "production") ? 1 : 0

  depends_on      = [railway_project.staging]
  create_duration = "40s"
}

resource "railway_project" "production" {
  count = contains(var.environments_to_create, "production") ? 1 : 0

  name         = "${var.project_name}-production"
  workspace_id = var.workspace_id
  default_environment = {
    name = "production"
  }

  depends_on = [time_sleep.before_production]
}
