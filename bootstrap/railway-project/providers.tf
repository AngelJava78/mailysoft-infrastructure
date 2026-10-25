# Autenticacion con un Account Token de uso EXCLUSIVO para este bootstrap (research.md
# seccion 2). Este token nunca se usa en el pipeline; tras aplicar este modulo una vez, se
# emiten Project Tokens por entorno desde el dashboard de Railway para uso continuo del
# pipeline, y este Account Token se revoca o se guarda fuera del repositorio solo para
# futuras re-ejecuciones puntuales de este bootstrap.
provider "railway" {
  token = var.railway_account_token
}
