variable "railway_account_token" {
  type        = string
  description = "Account Token de Railway, de uso exclusivo y puntual para este bootstrap. Nunca se usa en el pipeline ni se commitea; pasarlo via variable de entorno TF_VAR_railway_account_token."
  sensitive   = true
}

variable "project_name" {
  type        = string
  description = "Prefijo de nombre para los proyectos Railway de MailySoft; cada entorno de la plataforma recibe su propio proyecto \"<project_name>-<entorno>\" (ADR 0006)."
  default     = "maily-soft"
}

variable "environments_to_create" {
  type        = list(string)
  description = "Que proyectos de Railway crear en este apply (uno por entorno de la plataforma). Permite crear \"dev\" ahora y agregar \"staging\"/\"production\" en applies posteriores, dias o semanas despues (ADR 0006) -- cada apply debe incluir todos los entornos que deban seguir existiendo, no solo el nuevo."
  default     = ["dev"]
}

variable "workspace_id" {
  type        = string
  description = "Id del workspace de Railway donde crear el proyecto. Obligatorio en la practica: la API de Railway lo exige en cuanto el Account Token usado puede acceder a mas de un workspace (confirmado 2026-11-09 contra un apply real). Obtenerlo desde el dashboard de Railway: command palette (Ctrl/Cmd+K) sobre el workspace activo, o la API publica (docs.railway.com/reference/api)."
  default     = null
  nullable    = true
}
