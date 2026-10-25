variable "railway_account_token" {
  type        = string
  description = "Account Token de Railway, de uso exclusivo y puntual para este bootstrap. Nunca se usa en el pipeline ni se commitea; pasarlo via variable de entorno TF_VAR_railway_account_token."
  sensitive   = true
}

variable "project_name" {
  type        = string
  description = "Nombre del proyecto Railway que alojara todos los servicios de MailySoft."
  default     = "mailysoft"
}

variable "environment_names" {
  type        = list(string)
  description = "Railway Environments nativos a crear dentro del proyecto (uno por entorno de la plataforma)."
  default     = ["dev", "staging", "production"]
}
